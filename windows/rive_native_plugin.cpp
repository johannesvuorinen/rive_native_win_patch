#include "rive_native/rive_native_plugin.hpp"
#pragma warning(push)
#pragma warning(disable : 4702)
#include "spdlog/spdlog.h"
#pragma warning(pop)
#include "spdlog/sinks/win_eventlog_sink.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/flutter_view.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>
#include <cstdint>
#include <optional>
#include <unordered_map>
#include <functional>

using namespace spdlog;

// ===== PixelBuffer backing store per render texture =====
struct PixelBacking {
  std::vector<uint8_t> bgra;                 // width*height*4
  FlutterDesktopPixelBuffer fb{};            // {buffer,width,height}
  size_t width = 0, height = 0;

  Microsoft::WRL::ComPtr<ID3D11Device> device;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> staging;
};

static std::unordered_map<RiveNativeRenderTexture*, PixelBacking> g_pixelBacking;

// ============================================================================

static void onRendererEnd(void* userData)
{
    auto renderer = (RiveNativeRenderTexture*)userData;
    renderer->end();
}

static std::string convertWindowsString(WCHAR* wideString)
{
    int buffer_size = WideCharToMultiByte(CP_UTF8,
                                          0,
                                          wideString,
                                          -1,
                                          nullptr,
                                          0,
                                          nullptr,
                                          nullptr);
    char* narrow_buffer = new char[buffer_size];
    WideCharToMultiByte(CP_UTF8,
                        0,
                        wideString,
                        -1,
                        narrow_buffer,
                        buffer_size,
                        nullptr,
                        nullptr);
    std::string narrow_str(narrow_buffer);
    delete[] narrow_buffer;
    return narrow_str;
}

// ------------------- RiveNativeRenderTexture -------------------

RiveNativeRenderTexture::RiveNativeRenderTexture(
    ID3D11Device* gpu,
    void* riveRendererContext,
    uint32_t width,
    uint32_t height,
    flutter::TextureRegistrar* textureRegistrar) :
    m_flutterSurfaceDescs(),
    m_swapchain(
        makeSwapchainTexture(gpu, width, height, /*doClear=*/true),
        makeSwapchainTexture(gpu, width, height, /*doClear=*/false),
        makeSwapchainTexture(gpu, width, height, /*doClear=*/false),
        makeSwapchainTexture(gpu, width, height, /*doClear=*/false)),
    m_textureRegistrar(textureRegistrar)
{
    // Set up PixelBuffer backing
    PixelBacking& pb = g_pixelBacking[this];
    pb.width = width;
    pb.height = height;
    pb.bgra.resize(static_cast<size_t>(width) * static_cast<size_t>(height) * 4u);
    pb.fb.buffer = pb.bgra.data();
    pb.fb.width  = static_cast<size_t>(width);
    pb.fb.height = static_cast<size_t>(height);
    pb.device = gpu;

    m_textureVariant = std::make_unique<flutter::TextureVariant>(
        flutter::PixelBufferTexture(
            [this](size_t /*width*/, size_t /*height*/) -> const FlutterDesktopPixelBuffer* {
                auto it = g_pixelBacking.find(this);
                if (it == g_pixelBacking.end()) return nullptr;
                PixelBacking& pb = it->second;
                return &pb.fb;
            }));

    m_id = m_textureRegistrar->RegisterTexture(m_textureVariant.get());

    // Create Rive GPU renderer as before
    m_riveRenderer = createRiveRenderer(this,
                                        (void*)textureRegistrar,
                                        riveRendererContext,
                                        &m_swapchain,
                                        &onRendererEnd,
                                        width,
                                        height);
}

std::unique_ptr<FlutterWindowsTexture> RiveNativeRenderTexture::
    makeSwapchainTexture(ID3D11Device* gpu,
                         UINT width,
                         UINT height,
                         bool doClear)
{
    D3D11_TEXTURE2D_DESC desc{};
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 1;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.SampleDesc.Quality = 0;
    desc.Usage = D3D11_USAGE_DEFAULT;
    desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE |
                     D3D11_BIND_RENDER_TARGET;
    desc.CPUAccessFlags = 0;
    desc.MiscFlags = 0; // no longer need SHARED

    auto swapchainTexture = std::make_unique<FlutterWindowsTexture>();

    const D3D11_SUBRESOURCE_DATA* initialData = nullptr;
    std::vector<UINT> pixelData;
    D3D11_SUBRESOURCE_DATA initialDataStorage;
    if (doClear)
    {
        pixelData.resize(static_cast<size_t>(height) * static_cast<size_t>(width));
        memset(pixelData.data(), 0, pixelData.size() * sizeof(UINT));
        initialDataStorage.pSysMem = pixelData.data();
        initialDataStorage.SysMemPitch = width * sizeof(UINT);
        initialData = &initialDataStorage;
    }
    gpu->CreateTexture2D(
        &desc,
        initialData,
        swapchainTexture->nativeTexture.ReleaseAndGetAddressOf());

    swapchainTexture->flutterSurfaceDescIdx = m_flutterSurfaceDescs.size();
    m_flutterSurfaceDescs.emplace_back(FlutterDesktopGpuSurfaceDescriptor{
        sizeof(FlutterDesktopGpuSurfaceDescriptor),
        nullptr,
        static_cast<int>(width),
        static_cast<int>(height),
        static_cast<int>(width),
        static_cast<int>(height),
        kFlutterDesktopPixelFormatBGRA8888,
        [](void*) {},
        nullptr,
    });

    return swapchainTexture;
}

void RiveNativeRenderTexture::end()
{
    // Copy the just-presented GPU texture into our CPU BGRA buffer.
    auto it = g_pixelBacking.find(this);
    if (it != g_pixelBacking.end())
    {
        PixelBacking& pb = it->second;

        FlutterWindowsSwapchain::PresentingTextureLock lock(&m_swapchain);
        ID3D11Texture2D* src = lock.texture()->nativeTexture.Get();

        if (src && pb.device)
        {
            D3D11_TEXTURE2D_DESC srcDesc{};
            src->GetDesc(&srcDesc);

            if (!pb.staging) {
                D3D11_TEXTURE2D_DESC s = srcDesc;
                s.Usage = D3D11_USAGE_STAGING;
                s.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
                s.BindFlags = 0;
                s.MiscFlags = 0;
                pb.device->CreateTexture2D(&s, nullptr, pb.staging.ReleaseAndGetAddressOf());
            }

            Microsoft::WRL::ComPtr<ID3D11DeviceContext> ctx;
            pb.device->GetImmediateContext(&ctx);
            if (ctx) {
                ctx->CopyResource(pb.staging.Get(), src);
                D3D11_MAPPED_SUBRESOURCE mapped{};
                if (SUCCEEDED(ctx->Map(pb.staging.Get(), 0, D3D11_MAP_READ, 0, &mapped))) {
                    const uint8_t* srcRow = static_cast<const uint8_t*>(mapped.pData);
                    size_t rowBytes = static_cast<size_t>(srcDesc.Width) * 4u;
                    uint8_t* dstRow = pb.bgra.data();
                    for (UINT y = 0; y < srcDesc.Height; ++y) {
                        memcpy(dstRow, srcRow, rowBytes);
                        srcRow += mapped.RowPitch;
                        dstRow += rowBytes;
                    }
                    ctx->Unmap(pb.staging.Get(), 0);
                }
            }
        }
    }
    m_textureRegistrar->MarkTextureFrameAvailable(m_id);
}

RiveNativeRenderTexture::~RiveNativeRenderTexture()
{
    destroyRiveRenderer(m_riveRenderer);
    g_pixelBacking.erase(this);
}

// ------------------- RiveNativePlugin -------------------

void RiveNativePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar)
{
    auto plugin = std::make_unique<RiveNativePlugin>(
        registrar,
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(),
            "rive_native",
            &flutter::StandardMethodCodec::GetInstance()),
        registrar->texture_registrar());
    plugin->channel()->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });
    registrar->AddPlugin(std::move(plugin));
}

// Dart API
bool usePLS = true;

class FlutterRenderer;
namespace rive
{
class Font;
class RenderPath;
class AudioEngine;
} // namespace rive

EXPORT void rewindRenderPath(rive::RenderPath* path);

RiveNativePlugin::RiveNativePlugin(
    flutter::PluginRegistrarWindows* registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel,
    flutter::TextureRegistrar* texture_registrar) :
    m_registrar(registrar),
    m_channel(std::move(channel)),
    m_textureRegistrar(texture_registrar)
{
    auto sink =
        std::make_shared<spdlog::sinks::win_eventlog_sink_mt>("rive_native");
    sink->set_pattern("%v");
    auto logger = std::make_shared<spdlog::logger>("eventlog", sink);
    logger->set_level(spdlog::level::trace);
    spdlog::set_default_logger(logger);

    trace("RiveNativePlugin::RiveNativePlugin");

    // Create our own D3D11 device (independent of Flutter’s renderer).
    ComPtr<ID3D11Device> gpu;
    ComPtr<ID3D11DeviceContext> gpuContext;
    D3D_FEATURE_LEVEL featureLevels[] = {D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0};
    UINT creationFlags = 0;

    HRESULT result = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        NULL,
        creationFlags,
        featureLevels,
        (UINT)std::size(featureLevels),
        D3D11_SDK_VERSION,
        gpu.ReleaseAndGetAddressOf(),
        NULL,
        gpuContext.ReleaseAndGetAddressOf());

    if (result != S_OK) {
        info("Hardware D3D11 device failed, falling back to WARP (software).");
        result = D3D11CreateDevice(
            nullptr,
            D3D_DRIVER_TYPE_WARP,
            NULL,
            creationFlags,
            featureLevels,
            (UINT)std::size(featureLevels),
            D3D11_SDK_VERSION,
            gpu.ReleaseAndGetAddressOf(),
            NULL,
            gpuContext.ReleaseAndGetAddressOf());
    }

    if (!(gpu && gpuContext)) {
        error("Failed to init D3D11 device.");
        return;
    }

    bool isIntel = false;
    {
        ComPtr<IDXGIDevice> dxgiDevice;
        if (SUCCEEDED(gpu.As(&dxgiDevice))) {
            ComPtr<IDXGIAdapter> adapter;
            if (SUCCEEDED(dxgiDevice->GetAdapter(&adapter)) && adapter) {
                DXGI_ADAPTER_DESC desc{};
                if (SUCCEEDED(adapter->GetDesc(&desc))) {
                    isIntel = (desc.VendorId == 0x163C ||
                               desc.VendorId == 0x8086 ||
                               desc.VendorId == 0x8087);
                    info("Using D3D adapter for Rive: {}", convertWindowsString(desc.Description));
                }
            }
        }
    }

    m_gpu = std::move(gpu);
    m_gpuContext = std::move(gpuContext);
    m_isIntelGpu = isIntel;

    trace("Making renderer context");
    m_riveRendererContext = createRiveRendererContext(m_gpu, m_gpuContext, isIntel);
    trace("Made renderer context: {}", m_riveRendererContext);
}

RiveNativePlugin::~RiveNativePlugin()
{
    if (m_riveRendererContext != nullptr)
    {
        destroyRiveRendererContext(m_riveRendererContext);
    }
}

void RiveNativePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
{
    if (method_call.method_name().compare("createTexture") == 0)
    {
        if (m_riveRendererContext == nullptr)
        {
            result->Error("Rive Renderer is not suppored on this device.",
                          nullptr);
            return;
        }
        auto args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        auto widthItr = args->find(flutter::EncodableValue("width"));
        int32_t width = 0;
        if (widthItr != args->end())
            width = std::get<int32_t>(widthItr->second);
        else {
            result->Error("CreateTexture error", "No width", nullptr);
            return;
        }

        auto heightItr = args->find(flutter::EncodableValue("height"));
        int32_t height = 0;
        if (heightItr != args->end())
            height = std::get<int32_t>(heightItr->second);
        else {
            result->Error("CreateTexture error", "No height", nullptr);
            return;
        }

        auto renderTexture = new RiveNativeRenderTexture(m_gpu.Get(),
                                                         m_riveRendererContext,
                                                         width,
                                                         height,
                                                         m_textureRegistrar);
        if (auto it = g_pixelBacking.find(renderTexture); it != g_pixelBacking.end()) {
            it->second.device = m_gpu;
        }

        m_renderTextures[renderTexture->id()] = renderTexture;

        flutter::EncodableMap map;
        map[flutter::EncodableValue("textureId")] = renderTexture->id();

        char buff[255];
        snprintf(buff, 255, "%p", (void*)renderTexture->riveRenderer());
        map[flutter::EncodableValue("renderer")] = std::string(buff);
        result->Success(flutter::EncodableValue(map));
    }
    else if (method_call.method_name().compare("getRenderContext") == 0)
    {
        flutter::EncodableMap map;
        char buff[255];
        snprintf(buff, 255, "%p", factoryFromRiveRendererContext(m_riveRendererContext));
        map[flutter::EncodableValue("rendererContext")] = std::string(buff);
        result->Success(flutter::EncodableValue(map));
    }
    else if (method_call.method_name().compare("removeTexture") == 0)
    {
        auto args = std::get_if<flutter::EncodableMap>(method_call.arguments());
        auto idItr = args->find(flutter::EncodableValue("id"));
        int64_t id = 0;
        if (idItr != args->end())
            id = std::get<int64_t>(idItr->second);
        else {
            result->Error("removeTexture error", "no id", nullptr);
            return;
        }

        auto itr = m_renderTextures.find(id);
        if (itr != m_renderTextures.end())
        {
            auto renderTexture = itr->second;
            m_renderTextures.erase(itr);
            m_textureRegistrar->UnregisterTexture(renderTexture->id());
            delete renderTexture;
        }
        result->Success();
    }
    else
    {
        result->NotImplemented();
    }
}
