package com.chronoflow.backend.mindflow.agent;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Agent注册中心 — 利用Spring自动发现所有 MindFlowAgent Bean。
 *
 * 注册模式：Spring 构造器注入自动收集所有实现 MindFlowAgent 接口的 Bean，
 * 按 getIntentLabel() 建立意图标签 → Agent 的映射。
 *
 * 新增Agent只需实现 MindFlowAgent 接口并标注 @Component，无需修改本类。
 */
@Slf4j
@Component
public class AgentRegistry {

    private final Map<String, MindFlowAgent> agentMap;

    /**
     * Spring自动注入所有 MindFlowAgent 实现类。
     */
    public AgentRegistry(List<MindFlowAgent> agents) {
        this.agentMap = agents.stream()
                .collect(Collectors.toMap(
                        MindFlowAgent::getIntentLabel,
                        a -> a,
                        (existing, replacement) -> {
                            log.warn("重复的意图标签 {}，{} 将被 {} 覆盖",
                                    existing.getIntentLabel(),
                                    existing.getClass().getSimpleName(),
                                    replacement.getClass().getSimpleName());
                            return replacement;
                        }
                ));
        log.info("AgentRegistry 初始化完成，已注册 {} 个Agent: {}",
                agentMap.size(), agentMap.keySet());
    }

    /**
     * 根据意图标签解析对应Agent。
     *
     * @param intentLabel 意图标签（如 RESOURCE_GEN）
     * @return 对应的Agent实现，未匹配到返回 empty
     */
    public Optional<MindFlowAgent> resolve(String intentLabel) {
        return Optional.ofNullable(agentMap.get(intentLabel));
    }

    /**
     * 获取所有已注册的Agent数量。
     */
    public int size() {
        return agentMap.size();
    }
}