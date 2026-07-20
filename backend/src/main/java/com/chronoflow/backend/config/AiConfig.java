package com.chronoflow.backend.config;

import com.alibaba.cloud.ai.graph.agent.ReactAgent;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnExpression("!'${spring.ai.dashscope.api-key:not-configured}'.equals('not-configured')")
public class AiConfig {

    @Bean
    @ConditionalOnBean(ChatModel.class)
    public ReactAgent reactAgent(ChatModel chatModel) {
        return ReactAgent.builder()
                .name("notification-parser")
                .description("日程提取Agent")
                .model(chatModel)
                .outputSchema("""
                    {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "title": {"type": "string"},
                          "eventDate": {"type": "string"},
                          "eventTime": {"type": "string"},
                          "location": {"type": "string"},
                          "remark": {"type": "string"},
                          "category": {"type": "string"}
                        },
                        "required": ["title", "eventDate", "eventTime", "remark", "category"]
                      }
                    }
                    """)
                .build();
    }
}
