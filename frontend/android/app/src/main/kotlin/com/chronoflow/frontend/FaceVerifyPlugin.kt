package com.chronoflow.frontend

import com.alipay.face.api.ZIMFacade
import com.alipay.face.api.ZIMFacadeBuilder
import com.alipay.face.api.ZIMCallback
import com.alipay.face.api.ZIMResponse
import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.HashMap

/**
 * Platform Channel bridge for Alibaba Cloud Face Verification SDK v2.3.48.
 * Implements the ID_PRO scheme: name + ID card + liveness detection.
 *
 * SDK doc: https://help.aliyun.com/zh/id-verification/financial-grade-id-verification/
 */
class FaceVerifyPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var flutterBinding: FlutterPlugin.FlutterPluginBinding? = null

    // ---- FlutterPlugin ----

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "com.chronoflow/face_verify")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutterBinding = null
    }

    // ---- ActivityAware ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ---- MethodCallHandler ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctx = flutterBinding?.applicationContext
            ?: run {
                result.error("NO_CONTEXT", "Context not available", null)
                return
            }

        when (call.method) {
            "init" -> {
                try {
                    ZIMFacade.install(ctx)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("INIT_ERROR", e.message, null)
                }
            }

            "getMetaInfo" -> {
                try {
                    val metaInfo = ZIMFacade.getMetaInfos(ctx)
                    result.success(metaInfo)
                } catch (e: Exception) {
                    result.error("META_ERROR", e.message, null)
                }
            }

            "verify" -> {
                val certifyId = call.argument<String>("certifyId")
                if (certifyId.isNullOrEmpty()) {
                    result.error("INVALID_ARGS", "certifyId is required", null)
                    return
                }

                val act = activity
                if (act == null) {
                    result.error("NO_ACTIVITY", "Activity not available", null)
                    return
                }

                try {
                    // ZIMFacadeBuilder.create(activity).verify(certifyId, useMsgBox, extParams, callback)
                    ZIMFacadeBuilder.create(act).verify(
                        certifyId,
                        false,   // useMsgBox: false = no SDK popups, we handle UI
                        HashMap(), // extParams
                        object : ZIMCallback {
                            override fun response(response: ZIMResponse?): Boolean {
                                val code = response?.code ?: -1
                                val passed = code == 1000
                                act.runOnUiThread {
                                    result.success(mapOf(
                                        "passed" to passed,
                                        "message" to (response?.reason ?: "")
                                    ))
                                }
                                return true
                            }
                        }
                    )
                } catch (e: Exception) {
                    result.error("VERIFY_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }
}
