package com.chronoflow.backend.mindflow.agent;

import reactor.core.publisher.Flux;

/**Agent统一接口 — MindFlow 所有智能体的顶层抽象。*/
public interface MindFlowAgent {

    /**
     * 返回此Agent对应的意图标签
     * AgentRegistry 通过此标签进行路由匹配。
     */
    String getIntentLabel();

    /**
     * 执行Agent核心逻辑，返回流式事件。
     */
    Flux<AgentEvent> execute(AgentContext ctx);
}