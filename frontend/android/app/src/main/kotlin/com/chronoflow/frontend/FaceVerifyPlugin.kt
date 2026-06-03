package com.chronoflow.frontend

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Platform Channel bridge for Alibaba Cloud Face Verification SDK v2.3.48.
 *
 * To enable: download AARs from Alibaba Cloud → android/app/libs/
 * Then uncomment real SDK imports and replace stub implementations.
 */
class FaceVerifyPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var flutterBinding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterBinding = binding
        channel = MethodChannel(binding.binaryMessenger, "com.chronoflow/face_verify")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        flutterBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> result.success(null)
            "getMetaInfo" -> result.success("")
            "verify" -> result.success(mapOf(
                "passed" to false,
                "message" to "请集成阿里云人脸SDK后使用"
            ))
            else -> result.notImplemented()
        }
    }
}
