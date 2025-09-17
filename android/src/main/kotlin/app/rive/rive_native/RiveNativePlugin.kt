package app.rive.rive_native
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

external fun createRiveRenderer(
    surface: Surface,
    width: Int,
    height: Int,
): Long

external fun destroyRiveRenderer(renderer: Long)
external fun markDestroyedRiveRenderer(renderer: Long)

class RiveNativePlugin :
    FlutterPlugin,
    MethodCallHandler {
    companion object {
        init {
            System.loadLibrary("rive_native")
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var textureRegistry: TextureRegistry
    private val renderTextures = mutableMapOf<Long, RiveRenderTexture>()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "rive_native")
        channel.setMethodCallHandler(this)
        textureRegistry = flutterPluginBinding.textureRegistry
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "createTexture" -> {
                val width = call.argument<Int>("width")
                val height = call.argument<Int>("height")

                if (width == null || height == null) {
                    result.error(
                        "CreateTexture Error",
                        "Width and height are required",
                        null,
                    )
                    return
                }

                val surfaceProducer = textureRegistry.createSurfaceProducer()
                val riveTexture = RiveRenderTexture(surfaceProducer, width, height)
                renderTextures[surfaceProducer.id()] = riveTexture
                

                result.success(
                    mapOf(
                        "textureId" to surfaceProducer.id(),
                        "renderer" to riveTexture.riveRenderer.toString(16),
                    ),
                )
            }
            "getRenderContext" -> {
                result.success(
                    mapOf(
                        "rendererContext" to "android",
                    ),
                )
            }
            "removeTexture" -> {
                val textureId = call.argument<Integer>("id")?.toLong()
                if (textureId == null) {
                    result.error(
                        "removeTexture Error",
                        "Texture ID is required",
                        null,
                    )
                    return
                }

                renderTextures[textureId]?.let { texture ->
                    texture.release()
                    renderTextures.remove(textureId)
                    result.success(null)
                } ?: run {
                    result.error(
                        "removeTexture Error",
                        "Texture not found",
                        null,
                    )
                }
            }
            else -> result.notImplemented()
        }
    }
}

class RiveRenderTexture(
    surfaceProducer: TextureRegistry.SurfaceProducer,
    width: Int,
    height: Int,
) : TextureRegistry.SurfaceProducer.Callback {
    private val producer: TextureRegistry.SurfaceProducer
    private var surface: Surface
    public var riveRenderer: Long = 0

    init {
        producer = surfaceProducer
        producer.setSize(width, height)
        producer.setCallback(
            this,
        )

        surface = producer.getSurface()
        riveRenderer =
            createRiveRenderer(
                surface,
                width,
                height,
            )
    }

    // Called when coming back from backgrounding.
    override fun onSurfaceCreated() {
        // This should only happen when returning from backgrounding.
        markRendererDestroyed()
        // Make a new surface for Flutter to use, but we're going to build a new
        // texture shortly...
        surface = producer.getSurface()

    }

    override fun onSurfaceDestroyed() {
        // Do surface cleanup here, and stop drawing frames.
        markRendererDestroyed()
    }

    fun markRendererDestroyed() {
        if (riveRenderer != 0L) {
            markDestroyedRiveRenderer(riveRenderer)
        }
    }

    fun release() {
        if (riveRenderer != 0L) {
            destroyRiveRenderer(riveRenderer)
            riveRenderer = 0
        }
        surface.release()
    }
}
