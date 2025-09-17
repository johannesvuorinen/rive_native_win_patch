#include "rive_native/rive_binding.hpp"
#include "rive_native/external.hpp"
#include "lua.h"
#include "lualib.h"
#include "rive/lua/rive_lua_libs.hpp"
#include "rive/renderer.hpp"
#include "rive/viewmodel/viewmodel_instance_viewmodel.hpp"
#include "rive/core/binary_writer.hpp"
#include "rive/core/binary_stream.hpp"
#include "luau_error_parser.hpp"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>
#include <emscripten/html5.h>
#endif

#include <vector>
#include <chrono>

using namespace rive;

#ifdef __EMSCRIPTEN__
using namespace emscripten;
using ExternalPointer = WasmPtr;
using VoidCallback = emscripten::val;
#else
using ExternalPointer = void*;
typedef void (*VoidCallback)();
#endif

static int riveErrorHandler(lua_State* L);
static void* l_alloc(void* ud, void* ptr, size_t osize, size_t nsize)
{
    (void)ud;
    (void)osize;
    if (nsize == 0)
    {
        free(ptr);
        return NULL;
    }
    else
    {
        return realloc(ptr, nsize);
    }
}

class ConsoleMemoryStream : public rive::BinaryStream
{
public:
    ConsoleMemoryStream() {}

    void write(const uint8_t* bytes, std::size_t length) override
    {
        memory.insert(memory.end(), bytes, bytes + length);
    }

    void flush() override {}
    void clear() override { memory.clear(); }

    std::vector<uint8_t> memory;
};

static void interrupt(lua_State* L, int gc);

class DartExposedScriptingContext : public ScriptingContext
{
public:
#ifdef __EMSCRIPTEN__
    std::vector<emscripten::val> closures;
#endif
    ConsoleMemoryStream console;

    DartExposedScriptingContext(Factory* factory,
                                VoidCallback consoleHasDataCallback) :
        ScriptingContext(factory),
        m_consoleHasDataCallback(consoleHasDataCallback)
    {}

    void printError(lua_State* state) override
    {
        const char* error = lua_tostring(state, -1);
        auto parsed = ErrorParser::parse(error);

        writeError(parsed);
    }

    void printBeginLine(lua_State* state) override
    {
        BinaryWriter writer(&console);
        lua_Debug ar;
        lua_getinfo(state, 1, "sl", &ar);
        writer.write((uint8_t)0);
        writer.write(ar.source);
        writer.writeVarUint((uint32_t)ar.currentline);
    }

    void writeError(const ErrorParser::ParsedError& error)
    {
        BinaryWriter writer(&console);
        writer.write((uint8_t)1);

        writer.writeVarUint((uint64_t)error.filename.size());
        writer.write((const uint8_t*)error.filename.data(),
                     (size_t)error.filename.size());

        writer.writeVarUint((uint32_t)error.line_number.value_or(0));

        writer.writeVarUint((uint64_t)error.message.size());
        writer.write((const uint8_t*)error.message.data(),
                     (size_t)error.message.size());
        printEndLine();
    }

    void print(Span<const char> data) override
    {
        if (data.size() == 0)
        {
            return;
        }
        BinaryWriter writer(&console);
        writer.writeVarUint((uint64_t)data.size());
        writer.write((const uint8_t*)data.data(), (size_t)data.size());
    }

    void printEndLine() override
    {
        BinaryWriter writer(&console);
        writer.writeVarUint((uint32_t)0);
        // Tell Dart new data is available (if we haven't told it yet). Then
        // let dart read back all the written data so far.
        if (!m_calledConsoleCallback)
        {
            m_calledConsoleCallback = true;
            m_consoleHasDataCallback();
        }
    }

    void clearConsole()
    {
        console.clear();
        m_calledConsoleCallback = false;
    }

    Span<uint8_t> consoleMemory()
    {
        return Span<uint8_t>(console.memory.data(), console.memory.size());
    }

    void startTimedExecution(lua_State* state)
    {
        lua_Callbacks* cb = lua_callbacks(state);
        cb->interrupt = interrupt;
        executionTime = std::chrono::steady_clock::now();
    }

    void endTimedExecution(lua_State* state)
    {
        lua_Callbacks* cb = lua_callbacks(state);
        cb->interrupt = nullptr;
    }

    std::chrono::time_point<std::chrono::steady_clock> executionTime;

private:
    VoidCallback m_consoleHasDataCallback;
    bool m_calledConsoleCallback = false;
};

static void interrupt(lua_State* L, int gc)
{
    if (gc >= 0 || !lua_isyieldable(L))
    {
        return;
    }

    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(L));

    const auto now = std::chrono::steady_clock::now();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                  now - context->executionTime)
                  .count();
    if (ms > 50)
    {
        lua_Callbacks* cb = lua_callbacks(L);
        cb->interrupt = nullptr;
        // reserve space for error string
        lua_rawcheckstack(L, 1);
        luaL_error(L, "execution took too long");
    }
}

struct RiveLuauBufferResponse
{
#ifdef __EMSCRIPTEN__
    WasmPtr data;
#else
    uint8_t* data;
#endif
    size_t size;
};

EXPORT RiveLuauBufferResponse riveLuaConsole(lua_State* state)
{
    if (state == nullptr)
    {
        return {
#ifdef __EMSCRIPTEN__
            (WasmPtr) nullptr,
#else
            nullptr,
#endif
            0};
    }
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(state));
    auto memory = context->consoleMemory();

    return {
#ifdef __EMSCRIPTEN__
        (WasmPtr)memory.data(),
#else
        memory.data(),
#endif
        memory.size()};
}

EXPORT void riveLuaConsoleClear(lua_State* state)
{
    if (state == nullptr)
    {
        return;
    }
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(state));
    context->clearConsole();
}

EXPORT ExternalPointer riveLuaNewState(ExternalPointer factory,
                                       VoidCallback consoleHasDataCallback)
{
    auto context = new DartExposedScriptingContext((Factory*)factory,
                                                   consoleHasDataCallback);
    auto state = lua_newstate(l_alloc, nullptr);
    ScriptingVM::init(state, context);

    return (ExternalPointer)state;
}

EXPORT void riveLuaCloseState(lua_State* state)
{
    if (state == nullptr)
    {
        return;
    }
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(state));
    lua_close(state);
    delete context;
}

EXPORT void riveLuaCall(lua_State* state, int nargs, int nresults)
{
    try
    {
        lua_call(state, nargs, nresults);
    }
    catch (const std::exception& ex)
    {
        fprintf(stderr, "got lua exception %s\n", ex.what());
    }
}

EXPORT bool riveLuaRegisterModule(lua_State* state,
                                  const char* name,
                                  const char* data,
                                  size_t size)
{
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(state));
    context->startTimedExecution(state);
    auto result =
        ScriptingVM::registerModule(state,
                                    name,
                                    Span<uint8_t>((uint8_t*)data, size));
    context->endTimedExecution(state);
    return result;
}

EXPORT void riveLuaUnregisterModule(lua_State* state, const char* name)
{
    ScriptingVM::unregisterModule(state, name);
}

EXPORT bool riveLuaRegisterScript(lua_State* state,
                                  const char* name,
                                  const char* data,
                                  size_t size)
{
    return ScriptingVM::registerScript(state,
                                       name,
                                       Span<uint8_t>((uint8_t*)data, size));
}

EXPORT void riveStackDump(lua_State* state);
// Example C function to serve as an error handler
static int riveErrorHandler(lua_State* L)
{
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(L));
    context->printError(L);

    // lua_Debug ar;
    // lua_getinfo(L, 1, "sl", &ar);
    // // writer.write(ar.source);
    // // writer.writeVarUint((uint32_t)ar.currentline);
    // fprintf(stderr,
    //         "the source and line: %s %i\n",
    //         ar.source,
    //         (uint32_t)ar.currentline);
    // DartExposedScriptingContext* context =
    //     static_cast<DartExposedScriptingContext*>(lua_getthreaddata(L));
    // auto memory = context->consoleMemory();

    // Optionally, you can push a new value onto the stack to be returned by
    // lua_pcall For example, push a specific error code or a more detailed
    // message
    const char* error = lua_tostring(L, -1);
    lua_pushstring(L, error);
    return 1; // Number of return values
    // return 0;
}

EXPORT int riveLuaPCall(lua_State* state, int nargs, int nresults)
{
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(state));

    // calculate stack position for message handler
    int hpos = lua_gettop(state) - nargs;
    lua_pushcfunction(state, riveErrorHandler, "riveErrorHandler");
    lua_insert(state, hpos);

    context->startTimedExecution(state);
    int ret = lua_pcall(state, nargs, nresults, hpos);
    context->endTimedExecution(state);
    lua_remove(state, hpos);
    return ret;
}

EXPORT void riveLuaPushArtboard(lua_State* state,
                                WrappedArtboard* wrappedArtboard)
{
    if (state == nullptr || wrappedArtboard == nullptr)
    {
        return;
    }
    lua_newrive<ScriptedArtboard>(state,
                                  wrappedArtboard->file(),
                                  wrappedArtboard->artboard()->instance());
}

EXPORT ScriptedRenderer* riveLuaPushRenderer(lua_State* state,
                                             Renderer* renderer)
{
    if (state == nullptr || renderer == nullptr)
    {
        return nullptr;
    }
    return lua_newrive<ScriptedRenderer>(state, renderer);
}

EXPORT void riveLuaPushViewModelInstanceValue(
    lua_State* state,
    ViewModelInstanceValue* viewModelInstanceValue)
{
    if (state == nullptr || viewModelInstanceValue == nullptr)
    {
        return;
    }
    switch (viewModelInstanceValue->coreType())
    {
        case ViewModelInstanceViewModelBase::typeKey:
        {
            auto vm = viewModelInstanceValue->as<ViewModelInstanceViewModel>();
            auto vmi = vm->referenceViewModelInstance();
            if (vmi == nullptr)
            {
                fprintf(stderr,
                        "riveLuaPushViewModelInstanceValue - passed in a "
                        "ViewModelInstanceViewModel with no associated "
                        "ViewModelInstance.\n");
                return;
            }

            lua_newrive<ScriptedViewModel>(state,
                                           state,
                                           ref_rcp(vmi->viewModel()),
                                           vmi);
            break;
        }
        default:
            fprintf(stderr,
                    "riveLuaPushViewModelInstanceValue - passed in an "
                    "unhandled ViewModelInstanceValue type: %i\n",
                    viewModelInstanceValue->coreType());
            break;
    }
    // lua_newrive<ScriptedRenderer>(state, renderer);
}

EXPORT void riveLuaScriptedRendererEnd(ScriptedRenderer* renderer)
{
    if (renderer == nullptr)
    {
        return;
    }
    renderer->end();
}

EXPORT void riveStackDump(lua_State* state)
{
    int i;
    int top = lua_gettop(state);
    for (i = 1; i <= top; i++)
    { /* repeat for each level */
        int t = lua_type(state, i);
        switch (t)
        {

            case LUA_TSTRING: /* strings */
                fprintf(stderr,
                        "  (%i)[STRING] %s\n",
                        i,
                        lua_tostring(state, i));
                break;

            case LUA_TBOOLEAN: /* booleans */
                fprintf(stderr,
                        "  (%i)[BOOLEAN] %s\n",
                        i,
                        lua_toboolean(state, i) ? "true" : "false");
                break;

            case LUA_TNUMBER: /* numbers */
                fprintf(stderr,
                        "  (%i)[NUMBER] %g\n",
                        i,
                        lua_tonumber(state, i));
                break;

            default: /* other values */
                fprintf(stderr, "  (%i)[%s]\n", i, lua_typename(state, t));
                break;
        }
    }
    fprintf(stderr, "\n"); /* end the listing */
}
#ifdef __EMSCRIPTEN__

static int lua_callback(lua_State* L)
{
    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(L));
    unsigned functionIndex = lua_tounsignedx(L, lua_upvalueindex(1), nullptr);
    emscripten::val result =
        context->closures[functionIndex]((WasmPtr)L, functionIndex);
    return result.as<int>();
}

EXPORT void riveLuaPushClosure(WasmPtr state,
                               emscripten::val fn,
                               WasmPtr debugname)
{
    lua_State* L = (lua_State*)state;
    const char* name = (const char*)debugname;

    if (L == nullptr)
    {
        return;
    }

    DartExposedScriptingContext* context =
        static_cast<DartExposedScriptingContext*>(lua_getthreaddata(L));

    int upvalue = (int)context->closures.size();
    context->closures.push_back(fn);
    lua_pushinteger(L, upvalue);
    lua_pushcclosurek(L, lua_callback, name, 2, nullptr);
}

EMSCRIPTEN_BINDINGS(RiveLuauBinding)
{
    function("riveLuaPushClosure", &riveLuaPushClosure);
    function("riveLuaNewState", &riveLuaNewState);

    value_array<RiveLuauBufferResponse>("RiveLuauBufferResponse")
        .element(&RiveLuauBufferResponse::data)
        .element(&RiveLuauBufferResponse::size);

    function("riveLuaConsole",
             optional_override([](WasmPtr state) -> RiveLuauBufferResponse {
                 return riveLuaConsole((lua_State*)state);
             }));
}
#endif