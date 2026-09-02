package com.chronoflow.backend.service.excel;

import com.chronoflow.backend.dto.GroupImportItem;
import com.chronoflow.backend.dto.MemberInfo;
import com.chronoflow.backend.exception.BusinessException;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.util.*;

@Slf4j
@Service
public class ExcelParser {

    public List<GroupImportItem> parse(byte[] excelBytes) {
        Map<String, GroupImportItem> itemByName = new LinkedHashMap<>();
        try (Workbook workbook = new XSSFWorkbook(new ByteArrayInputStream(excelBytes))) {
            Sheet sheet = workbook.getSheetAt(0);
            int lastRow = sheet.getLastRowNum();

            for (int i = 1; i <= lastRow; i++) {
                Row row = sheet.getRow(i);
                if (row == null || isEmptyRow(row)) continue;

                String groupName = getCellString(row, 0);
                String description = getCellString(row, 1);
                String parentName = getCellString(row, 2);
                String memberName = getCellString(row, 3);
                String studentId = getCellString(row, 4);
                String email = getCellString(row, 5);
                String phone = getCellString(row, 6);
                boolean requireApproval = parseApproval(getCellString(row, 7));

                MemberInfo member = MemberInfo.builder()
                        .name(memberName)
                        .studentId(studentId)
                        .email(email)
                        .phone(phone)
                        .build();

                GroupImportItem item = itemByName.get(groupName);
                if (item == null) {
                    List<MemberInfo> rawMembers = new ArrayList<>();
                    if (!phone.isBlank()) {
                        rawMembers.add(member);
                    }
                    item = GroupImportItem.builder()
                            .rowNumber(i + 1)
                            .name(groupName)
                            .description(description)
                            .parentName(parentName)
                            .requireApproval(requireApproval)
                            .rawMembers(rawMembers)
                            .memberPhones(Collections.emptyList())
                            .members(Collections.emptyList())
                            .build();
                    itemByName.put(groupName, item);
                } else {
                    if (!phone.isBlank()) {
                        mergeMember(item, member);
                    }
                }
            }
            return new ArrayList<>(itemByName.values());
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("Excel parse failed: {}", e.getMessage());
            throw new BusinessException("文件格式错误，请使用 .xlsx 格式模板");
        }
    }

    private void mergeMember(GroupImportItem item, MemberInfo member) {
        List<MemberInfo> rawMembers = item.getRawMembers();
        for (MemberInfo existing : rawMembers) {
            if (existing.getPhone().equals(member.getPhone())) {
                if (existing.getName() == null || existing.getName().isBlank()) {
                    existing.setName(member.getName());
                }
                if (existing.getStudentId() == null || existing.getStudentId().isBlank()) {
                    existing.setStudentId(member.getStudentId());
                }
                if (existing.getEmail() == null || existing.getEmail().isBlank()) {
                    existing.setEmail(member.getEmail());
                }
                return;
            }
        }
        rawMembers.add(member);
    }

    private boolean isEmptyRow(Row row) {
        for (int i = 0; i < 8; i++) {
            String val = getCellString(row, i);
            if (val != null && !val.isBlank()) return false;
        }
        return true;
    }

    private String getCellString(Row row, int col) {
        Cell cell = row.getCell(col);
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue().trim();
            case NUMERIC -> String.valueOf((long) cell.getNumericCellValue());
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> "";
        };
    }

    private boolean parseApproval(String val) {
        return "是".equals(val.trim());
    }
}
