package com.chronoflow.backend.mindflow.tool;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

/**
 * 知识库语义检索工具 — 向量+关键词混合检索课程知识库。
 *
 * MVP实现：基于内存的关键词匹配检索引擎。
 * 设计文档中规划的 Milvus Lite + 星火 Embedding API 为后续增强方向。
 *
 * 当前MVP提供：
 * - 关键词分词与匹配
 * - 简单的相关性评分
 * - 缓存热点查询结果（6小时）
 */
@Slf4j
@Component
public class KnowledgeSearchTool {

    /** 知识库条目 */
    private final Map<String, KnowledgeEntry> knowledgeBase = new ConcurrentHashMap<>();

    /** 检索缓存 */
    private final Map<String, CacheEntry> searchCache = new ConcurrentHashMap<>();

    /**
     * 初始化知识库，注册示例知识条目（MVP演示数据）。
     */
    public KnowledgeSearchTool() {
        // 注册示例知识条目用于赛事演示
        register("决策树", "决策树是一种监督学习算法，用于分类和回归任务。通过树状结构进行决策。", List.of("机器学习", "决策树", "分类"));
        register("信息增益", "信息增益是决策树中用于选择最优划分属性的指标，基于熵的减少量。", List.of("决策树", "信息论", "特征选择"));
        register("剪枝", "剪枝是防止决策树过拟合的技术，包括预剪枝和后剪枝两种策略。", List.of("决策树", "正则化", "模型优化"));
        register("神经网络", "神经网络是受人脑启发的计算模型，由多层神经元组成，用于深度学习。", List.of("深度学习", "神经网络", "反向传播"));
        register("Python基础", "Python是一种解释型、面向对象的高级编程语言，广泛用于数据科学和机器学习。", List.of("Python", "编程语言", "入门"));
        log.info("KnowledgeSearchTool 初始化完成，已注册 {} 条知识条目", knowledgeBase.size());
    }

    /**
     * 注册知识条目。
     */
    public void register(String title, String content, List<String> keywords) {
        knowledgeBase.put(title, new KnowledgeEntry(title, content, keywords));
    }

    /**
     * 混合检索：关键词匹配 + 简单语义相关性评分。
     *
     * @param query 检索查询
     * @param topK  返回Top-K结果
     * @return 检索结果列表（按相关性降序）
     */
    public List<SearchResult> search(String query, int topK) {
        // 检查缓存
        String cacheKey = query + "_" + topK;
        CacheEntry cached = searchCache.get(cacheKey);
        if (cached != null && !cached.isExpired()) {
            log.info("知识库检索缓存命中: {}", query);
            return cached.results;
        }

        // 分词（简单空格+标点分词）
        Set<String> queryTokens = tokenize(query);

        // 计算每条知识条目的相关性分数
        List<SearchResult> results = knowledgeBase.values().stream()
                .map(entry -> {
                    double score = calculateRelevance(queryTokens, entry);
                    return new SearchResult(entry.title, entry.content, score);
                })
                .filter(r -> r.score > 0)
                .sorted(Comparator.comparingDouble(SearchResult::getScore).reversed())
                .limit(topK)
                .collect(Collectors.toList());

        // 缓存结果（6小时）
        searchCache.put(cacheKey, new CacheEntry(results));
        log.info("知识库检索完成: query={}, 结果数={}", query, results.size());
        return results;
    }

    /**
     * 简易分词（空格、标点、中文字符拆分）。
     */
    private Set<String> tokenize(String text) {
        Set<String> tokens = new HashSet<>();
        // 按空格和常见标点拆分
        for (String part : text.split("[\\s，,。.！!？?、：:；;（）()\\[\\]{}]+")) {
            if (!part.isEmpty()) {
                tokens.add(part.toLowerCase());
                // 中文2-gram
                if (part.length() >= 2) {
                    for (int i = 0; i < part.length() - 1; i++) {
                        tokens.add(part.substring(i, i + 2));
                    }
                }
            }
        }
        return tokens;
    }

    /**
     * 计算查询与知识条目的相关性分数。
     */
    private double calculateRelevance(Set<String> queryTokens, KnowledgeEntry entry) {
        int matchCount = 0;
        for (String token : queryTokens) {
            if (token.length() < 2) continue;
            // 标题匹配权重更高
            if (entry.title.toLowerCase().contains(token)) {
                matchCount += 3;
            }
            // 关键词匹配
            for (String kw : entry.keywords) {
                if (kw.toLowerCase().contains(token) || token.contains(kw.toLowerCase())) {
                    matchCount += 2;
                }
            }
            // 内容匹配
            if (entry.content.toLowerCase().contains(token)) {
                matchCount += 1;
            }
        }
        return Math.min(matchCount / 10.0, 1.0);
    }

    /** 知识条目 */
    record KnowledgeEntry(String title, String content, List<String> keywords) {}

    /** 检索结果 */
    @lombok.Data
    @lombok.AllArgsConstructor
    public static class SearchResult {
        private String title;
        private String content;
        private double score;
    }

    /** 缓存条目（6小时过期） */
    private static class CacheEntry {
        final List<SearchResult> results;
        final long timestamp;

        CacheEntry(List<SearchResult> results) {
            this.results = results;
            this.timestamp = System.currentTimeMillis();
        }

        boolean isExpired() {
            return System.currentTimeMillis() - timestamp > 6 * 3600_000L;
        }
    }
}