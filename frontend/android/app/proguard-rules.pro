# 阿里云实人认证 SDK 混淆配置 (v2.3.48)
# 文档: https://help.aliyun.com/zh/id-verification/

# 必须要依赖到应用混淆中
-keepclassmembers,allowobfuscation class * {
     @com.alibaba.fastjson.annotation.JSONField <fields>;
}
-keep class net.security.device.api.** {*;}
-keep class face.security.device.api.** {*;}
-keep class com.alipay.deviceid.** { *; }
-keep class org.json.** { *;}
-keep class com.alibaba.fastjson.** {*;}

# SDK混淆配置
-keep class com.alipay.face.network.PopNetHelper { *; }
-keep class com.alipay.face.api.** {*;}
-keep class com.alipay.zoloz.toyger.**{*;}
-keep class com.dtf.face.api.** {*;}
-keep class com.dtf.face.ocr.verify.DTFOcrFacade { *; }
-keep class com.dtf.face.verify.** {*;}
-keep class com.dtf.face.network.model.** {*;}
-keep class com.dtf.face.network.APICallback {*;}
-keep class com.dtf.face.config.**{*;}
-keep class com.dtf.face.log.** {*;}
-keep class com.dtf.face.ui.overlay.** {*;}
-keep class com.dtf.face.ui.widget.ToygerWebView {*;}
-keep class com.dtf.face.utils.ClientConfigUtil{
   boolean needUploadPreviewTrace*();
   boolean needVideoExDegrade*();
   boolean isCfgVideoExDevice*();
}
-keep class com.dtf.toyger.base.** {*;}
-keep class com.dtf.face.network.mpass.biz.model.** { *; }
-keep class com.dtf.face.utils.LogUtils { *; }
-keep class com.dtf.wish.api.** { *; }
-keep class com.dtf.wish.ui.** { *; }
-keep class com.dtf.wish.ui.WishFragment{*;}
-keep class com.dtf.voice.api.** { *; }
-keep class xnn.* { *; }
-keep class facadeverify.** { *; }
-keep class baseverify.** { *; }
-keep class faceverify.** { *; }
-keep class ocrverify.** { *; }
-keep class wishverify.** { *; }
-keep class com.dtf.face.camera.render.**{ *;}

# R8编译混淆配置
-keep class com.dtf.face.ui.toyger.FaceLoadingFragment{ *; }
-keep class com.dtf.face.ui.toyger.FaceShowFragment{*;}
-keep class com.dtf.face.ui.toyger.FaceShowElderlyFragment{*;}
-keepclassmembers class com.dtf.face.camera.ICameraCallback{
   void onPreviewFrame*(*);
}

# 忽略警告
-dontwarn okio.**
-dontwarn org.apache.commons.codec.binary.**
