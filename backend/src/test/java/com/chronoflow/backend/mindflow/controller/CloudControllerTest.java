package com.chronoflow.backend.mindflow.controller;

import com.chronoflow.backend.dto.ApiResponse;
import com.chronoflow.backend.mindflow.dto.CloudDirectoryResponse;
import com.chronoflow.backend.mindflow.dto.ResourceResponse;
import com.chronoflow.backend.mindflow.service.CloudService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * CloudController 单元测试 — 云盘接口。
 */
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("CloudController 云盘测试")
class CloudControllerTest {

    @Mock private CloudService cloudService;
    @Mock private HttpServletRequest request;

    @InjectMocks private CloudController cloudController;

    @BeforeEach
    void setUp() {
        when(request.getAttribute("userId")).thenReturn(100L);
    }

    @Test
    @DisplayName("getDirectory 应返回 5 个文件夹的目录结构")
    void getDirectory_shouldReturn5Folders() {
        when(cloudService.getDirectory(100L))
                .thenReturn(CloudDirectoryResponse.builder()
                        .folders(List.of(
                                CloudDirectoryResponse.FolderInfo.builder()
                                        .type("DOC").name("讲解文档").icon("description").count(3).build(),
                                CloudDirectoryResponse.FolderInfo.builder()
                                        .type("MINDMAP").name("思维导图").icon("account_tree").count(2).build(),
                                CloudDirectoryResponse.FolderInfo.builder()
                                        .type("QUIZ").name("练习题").icon("quiz").count(5).build(),
                                CloudDirectoryResponse.FolderInfo.builder()
                                        .type("READING").name("拓展材料").icon("menu_book").count(1).build(),
                                CloudDirectoryResponse.FolderInfo.builder()
                                        .type("CODE").name("代码案例").icon("code").count(4).build()
                        )).build());

        ResponseEntity<ApiResponse<CloudDirectoryResponse>> response = cloudController.getDirectory(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getData().getFolders()).hasSize(5);
        assertThat(response.getBody().getData().getFolders().get(2).getType()).isEqualTo("QUIZ");
        assertThat(response.getBody().getData().getFolders().get(2).getCount()).isEqualTo(5);
    }

    @Test
    @DisplayName("getDirectory 空用户应返回空目录")
    void getDirectory_emptyUser_shouldReturnEmpty() {
        when(cloudService.getDirectory(100L))
                .thenReturn(CloudDirectoryResponse.builder().folders(List.of()).build());

        ResponseEntity<ApiResponse<CloudDirectoryResponse>> response = cloudController.getDirectory(request);

        assertThat(response.getBody().getData().getFolders()).isEmpty();
    }

    @Test
    @DisplayName("getFolderContent 应返回指定文件夹的资源列表")
    void getFolderContent_shouldReturnResources() {
        when(cloudService.getFolderContent(100L, "QUIZ")).thenReturn(List.of(
                ResourceResponse.builder().id(1L).resourceType("QUIZ")
                        .title("q1").content("c1").confidenceScore(new BigDecimal("0.8"))
                        .reviewed(true).version(1).build(),
                ResourceResponse.builder().id(2L).resourceType("QUIZ")
                        .title("q2").content("c2").confidenceScore(new BigDecimal("0.9"))
                        .reviewed(true).version(1).build()
        ));

        ResponseEntity<ApiResponse<List<ResourceResponse>>> response = cloudController.getFolderContent(request, "QUIZ");

        assertThat(response.getBody().getData()).hasSize(2);
        assertThat(response.getBody().getData().get(0).getResourceType()).isEqualTo("QUIZ");
    }

    @Test
    @DisplayName("getFolderContent 小写 type 应转为大写")
    void getFolderContent_lowercaseType_shouldBeUppercased() {
        when(cloudService.getFolderContent(100L, "DOC")).thenReturn(List.of());

        ResponseEntity<ApiResponse<List<ResourceResponse>>> response = cloudController.getFolderContent(request, "doc");

        verify(cloudService, times(1)).getFolderContent(100L, "doc");
    }
}