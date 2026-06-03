package com.chronoflow.backend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/app")
public class AppController {

    @Value("${app.version:1.0.0}")
    private String version;

    @Value("${app.version-code:1}")
    private int versionCode;

    @Value("${app.download-url:}")
    private String downloadUrl;

    @GetMapping("/version")
    public ResponseEntity<Map<String, Object>> getVersion() {
        return ResponseEntity.ok(Map.of(
                "version", version,
                "versionCode", versionCode,
                "downloadUrl", downloadUrl
        ));
    }
}
