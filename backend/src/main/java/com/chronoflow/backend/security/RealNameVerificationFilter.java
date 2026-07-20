package com.chronoflow.backend.security;

import com.chronoflow.backend.entity.User;
import com.chronoflow.backend.mapper.UserMapper;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.util.Set;

/**
 * Blocks unverified users from accessing restricted endpoints.
 * Users without realNameVerified can only use:
 * - Public auth endpoints (/api/auth/**)
 * - Schedule CRUD (/api/schedules/**)
 * - User info + verification endpoints (/api/user/info, /api/user/real-person-verify/**)
 */
@Slf4j
// @Component — disabled, enable when face SDK is ready
@RequiredArgsConstructor
public class RealNameVerificationFilter implements Filter {

    private final UserMapper userMapper;

    private static final Set<String> ALLOWED_PREFIXES = Set.of(
            "/api/auth/", "/api/schedules/", "/actuator/"
    );
    private static final Set<String> ALLOWED_EXACT = Set.of(
            "/api/user/info", "/api/user/real-person-verify", "/api/user/real-person-verify/result"
    );

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        String path = httpRequest.getRequestURI();
        String method = httpRequest.getMethod();

        // OPTIONS (CORS preflight) always allowed
        if ("OPTIONS".equalsIgnoreCase(method)) {
            chain.doFilter(request, response);
            return;
        }

        // Check if path is in allowed list
        boolean allowed = false;
        for (String prefix : ALLOWED_PREFIXES) {
            if (path.startsWith(prefix)) { allowed = true; break; }
        }
        if (!allowed) {
            for (String exact : ALLOWED_EXACT) {
                if (path.equals(exact)) { allowed = true; break; }
            }
        }
        if (allowed) {
            chain.doFilter(request, response);
            return;
        }

        // Check user verification status
        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            chain.doFilter(request, response);
            return;
        }

        User user = userMapper.selectById(userId);
        if (user != null && Boolean.TRUE.equals(user.getRealNameVerified())) {
            chain.doFilter(request, response);
            return;
        }

        // Block: user not verified
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        httpResponse.setContentType("application/json;charset=UTF-8");
        httpResponse.setStatus(403);
        httpResponse.getWriter().write("{\"code\":403,\"message\":\"请先完成实名认证\"}");
    }
}
