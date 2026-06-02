package com.chronoflow.backend.controller;

import com.chronoflow.backend.dto.ScheduleRequest;
import com.chronoflow.backend.dto.ScheduleResponse;
import com.chronoflow.backend.service.ScheduleService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@Slf4j
@RestController
@RequestMapping("/api/schedules")
@RequiredArgsConstructor
public class ScheduleController {

    private final ScheduleService scheduleService;

    @PostMapping
    public ResponseEntity<ScheduleResponse> createSchedule(
            HttpServletRequest request,
            @Valid @RequestBody ScheduleRequest scheduleRequest) {
        log.info("POST /api/schedules - title: {}, time: {}", scheduleRequest.getTitle(), scheduleRequest.getTime());
        Long userId = getUserIdFromRequest(request);
        ScheduleResponse response = scheduleService.createSchedule(userId, scheduleRequest);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/group")
    public ResponseEntity<ScheduleResponse> createGroupSchedule(
            HttpServletRequest request,
            @Valid @RequestBody ScheduleRequest scheduleRequest,
            @RequestParam String groupId) {
        log.info("POST /api/schedules/group - groupId: {}, title: {}", groupId, scheduleRequest.getTitle());
        Long userId = getUserIdFromRequest(request);
        ScheduleResponse response = scheduleService.createGroupSchedule(userId, groupId, scheduleRequest);
        return ResponseEntity.ok(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ScheduleResponse> updateSchedule(
            HttpServletRequest request,
            @PathVariable Long id,
            @Valid @RequestBody ScheduleRequest scheduleRequest) {
        Long userId = getUserIdFromRequest(request);
        ScheduleResponse response = scheduleService.updateSchedule(userId, id, scheduleRequest);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteSchedule(
            HttpServletRequest request,
            @PathVariable Long id) {
        Long userId = getUserIdFromRequest(request);
        scheduleService.deleteSchedule(userId, id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/{id}")
    public ResponseEntity<ScheduleResponse> getSchedule(
            HttpServletRequest request,
            @PathVariable Long id) {
        Long userId = getUserIdFromRequest(request);
        ScheduleResponse response = scheduleService.getSchedule(userId, id);
        return ResponseEntity.ok(response);
    }

    @GetMapping
    public ResponseEntity<List<ScheduleResponse>> getSchedules(
            HttpServletRequest request,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam(required = false) String search) {
        Long userId = getUserIdFromRequest(request);
        List<ScheduleResponse> schedules;
        if (search != null && !search.isEmpty()) {
            schedules = scheduleService.searchSchedules(userId, search);
        } else if (date != null) {
            schedules = scheduleService.getSchedulesByDate(userId, date);
        } else {
            schedules = scheduleService.getAllSchedules(userId);
        }
        return ResponseEntity.ok(schedules);
    }

    @GetMapping("/group")
    public ResponseEntity<List<ScheduleResponse>> getGroupSchedules(HttpServletRequest request) {
        Long userId = getUserIdFromRequest(request);
        List<ScheduleResponse> schedules = scheduleService.getAllGroupSchedules(userId);
        return ResponseEntity.ok(schedules);
    }

    private Long getUserIdFromRequest(HttpServletRequest request) {
        return (Long) request.getAttribute("userId");
    }
}