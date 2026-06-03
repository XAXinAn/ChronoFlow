# ===== Flutter =====
-keep class io.flutter.** { *; }

# ===== ML Kit =====
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ===== Alibaba Cloud Face SDK =====
-keep class com.alipay.face.** { *; }
-keep class com.alipay.zoloz.** { *; }
-keep class com.dtf.face.** { *; }
-keep class com.dtf.toyger.** { *; }
-keep class com.dtf.wish.** { *; }
-keep class com.dtf.voice.** { *; }
-keep class faceverify.** { *; }
-keep class baseverify.** { *; }
-keep class facadeverify.** { *; }
-keep class ocrverify.** { *; }
-keep class wishverify.** { *; }
-keep class xnn.** { *; }

# ===== Alibaba Cloud security =====
-keep class net.security.device.api.** { *; }
-keep class face.security.device.api.** { *; }
-keep class com.alipay.deviceid.** { *; }

# ===== fastjson =====
-keep class com.alibaba.fastjson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.alibaba.fastjson.annotation.JSONField <fields>;
}
-dontwarn com.alibaba.fastjson.**
-dontwarn com.google.common.**
-dontwarn org.joda.**
-dontwarn java.awt.**
-dontwarn javax.money.**
-dontwarn org.javamoney.**
-dontwarn springfox.**

# ===== okhttp/okio =====
-dontwarn okhttp3.**
-dontwarn okio.**
