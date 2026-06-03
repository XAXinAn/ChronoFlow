package com.chronoflow.backend.security;

import jakarta.servlet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Simple in-memory rate limiting filter for auth endpoints.
 * Limits requests per IP to prevent brute-force attacks and SMS bombing.
 * For production, consider using Redis-based rate limiting.
 */
@Slf4j
@Component
public class RateLimitingFilter implements Filter {

    // Per-IP request count with timestamp
    private static final Map<String, long[]> requestCounts = new ConcurrentHashMap<>();

    // Rate limits: endpoint prefix -> (max requests, window in milliseconds)
    private static final Map<String, RateLimit> LIMITS = Map.of(
            "/api/auth/send-sms", new RateLimit(5, 60_000),       // 5 SMS per minute per IP
            "/api/auth/send-email", new RateLimit(5, 60_000),     // 5 emails per minute per IP
            "/api/auth/login", new RateLimit(20, 60_000),         // 20 login attempts per minute per IP
            "/api/auth/register", new RateLimit(5, 60_000),       // 5 registration inits per minute per IP
            "/api/auth/register/confirm", new RateLimit(10, 60_000), // 10 registration confirms per minute per IP
            "/api/auth/sms-login", new RateLimit(10, 60_000),     // 10 SMS login attempts per minute per IP
            "/api/auth/email-login", new RateLimit(10, 60_000),   // 10 email login attempts per minute per IP
            "/api/groups", new RateLimit(10, 60_000)              // 10 group creations per minute per IP
    );

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        String path = httpRequest.getRequestURI();
        String method = httpRequest.getMethod();

        // Only rate-limit POST requests to auth endpoints
        if (!"POST".equalsIgnoreCase(method)) {
            chain.doFilter(request, response);
            return;
        }

        RateLimit limit = LIMITS.get(path);
        if (limit == null) {
            chain.doFilter(request, response);
            return;
        }

        String clientIp = getClientIp(httpRequest);
        String key = path + ":" + clientIp;
        long now = System.currentTimeMillis();

        long[] entry = requestCounts.compute(key, (k, v) -> {
            if (v == null || now - v[1] > limit.windowMs) {
                return new long[]{1, now};
            }
            v[0]++;
            return v;
        });

        if (entry[0] > limit.maxRequests) {
            log.warn("Rate limit exceeded: path={}, ip={}, count={}", path, clientIp, entry[0]);
            HttpServletResponse httpResponse = (HttpServletResponse) response;
            httpResponse.setContentType("application/json;charset=UTF-8");
            httpResponse.setStatus(429);
            httpResponse.getWriter().write("{\"code\":429,\"message\":\"请求过于频繁，请稍后重试\"}");
            return;
        }

        chain.doFilter(request, response);
    }

    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank()) {
            return xForwardedFor.split(",")[0].trim();
        }
        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isBlank()) {
            return xRealIp.trim();
        }
        return request.getRemoteAddr();
    }

    private record RateLimit(int maxRequests, long windowMs) {}
}
