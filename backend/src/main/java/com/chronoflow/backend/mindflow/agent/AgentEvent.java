package com.chronoflow.backend.mindflow.agent;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

/**
 * Agent事件 — Agent执行过程中产生的流式事件单元。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AgentEvent {

    /** 事件类型 */
    private String type;

    /** 事件内容*/
    private String content;

    /** 进度阶段标识 */
    private String stage;

    /** 进度百分比 (0.0~1.0) */
    private double percent;

    /** 资源类型（RESOURCE_CARD类型时使用） */
    private String agent;

    /** 资源标题 */
    private String title;

    /** Mermaid图表源码（DIAGRAM类型时使用） */
    private String mermaid;

    /** 图表标题 */
    private String caption;

    /** 错误是否可重试 */
    private boolean retryable;

    /** 完成摘要 */
    private String summary;

    /** 生成的资源ID列表 */
    private java.util.List<Long> resources;

    /** 扩展数据（灵活附加信息） */
    private Map<String, Object> extra;
}