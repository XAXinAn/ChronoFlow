package com.chronoflow.backend.mindflow.tool;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 联网检索工具 — 资源生成前搜索最新资料作为事实参照。
 *
 * MVP实现：使用星火API的内置Web Search能力（通过 system prompt 注入搜索指令）。
 * P0阶段优先保证功能闭环，后续可替换为 SearXNG 或专业搜索API。
 *
 * 结果缓存1小时以减少重复API调用。
 */
@Slf4j
@Component
public class WebSearchTool {

    /** 搜索缓存（简单内存缓存，1小时过期） */
    private final ConcurrentHashMap<String, CacheEntry> cache = new ConcurrentHashMap<>();

    /**
     * 执行联网检索，返回结构化搜索结果。
     *
     * @param query 搜索关键词
     * @return 搜索结果摘要文本
     */
    public String search(String query) {
        // 检查缓存
        CacheEntry cached = cache.get(query);
        if (cached != null && !cached.isExpired()) {
            log.info("WebSearch缓存命中: {}", query);
            return cached.result;
        }

        // MVP阶段：返回知识提示引导AI生成
        // 实际联网检索需集成搜素引擎API（如SearXNG、Bing Search等）
        // 当前实现将搜索意图注入到Agent的system prompt中，由星火API利用其内置知识回答
        String result = buildSearchContext(query);

        // 缓存结果
        cache.put(query, new CacheEntry(result));
        log.info("WebSearch完成: {}, 结果长度={}", query, result.length());
        return result;
    }

    /**
     * MVP实现：构建搜索上下文提示。
     * 告诉下游Agent在生成内容时应参考哪些方面的最新信息。
     */
    private String buildSearchContext(String query) {
        return String.format("""
                【联网检索上下文 - %s】
                请基于以下检索方向生成内容：
                1. 该知识点的核心概念与定义
                2. 最新的应用场景与发展趋势
                3. 常见的学习难点与误区
                4. 推荐的学习路径与实践方法

                注意：请确保内容的准确性和时效性，对于不确定的信息请标注"AI生成，请核实"。
                """, query);
    }

    /**
     * 缓存条目。
     */
    private static class CacheEntry {
        final String result;
        final long timestamp;

        CacheEntry(String result) {
            this.result = result;
            this.timestamp = System.currentTimeMillis();
        }

        /** 1小时过期 */
        boolean isExpired() {
            return System.currentTimeMillis() - timestamp > Duration.ofHours(1).toMillis();
        }
    }
}