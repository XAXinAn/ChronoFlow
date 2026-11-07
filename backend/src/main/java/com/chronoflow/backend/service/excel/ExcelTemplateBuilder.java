package com.chronoflow.backend.service.excel;

import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;

@Slf4j
@Service
public class ExcelTemplateBuilder {

    public byte[] buildTemplate() {
        try (XSSFWorkbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {

            Sheet sheet = workbook.createSheet("群组导入模板");

            CellStyle headerStyle = workbook.createCellStyle();
            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.LIGHT_BLUE.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);

            Row headerRow = sheet.createRow(0);
            String[] headers = {"群组名称", "群组描述", "父群组名称", "成员姓名", "成员学号", "成员邮箱", "成员手机号", "加群是否需要审批"};
            for (int i = 0; i < headers.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(headers[i]);
                cell.setCellStyle(headerStyle);
            }

            Row descRow = sheet.createRow(1);
            String[] descs = {
                    "必填，1-100字符",
                    "选填，群组描述",
                    "选填，父群组名称，空表示顶级群组",
                    "选填，成员姓名，≤50字符",
                    "选填，成员学号，≤32字符",
                    "选填，成员邮箱",
                    "必填，11位手机号，每个成员独占一行",
                    "选填，是/否，默认否"
            };
            for (int i = 0; i < descs.length; i++) {
                descRow.createCell(i).setCellValue(descs[i]);
            }

            Row exampleRow1 = sheet.createRow(2);
            String[] example1 = {"技术部", "研发团队", "公司", "张三", "20260001", "zhangsan@example.com", "13800138000", "否"};
            for (int i = 0; i < example1.length; i++) {
                exampleRow1.createCell(i).setCellValue(example1[i]);
            }

            Row exampleRow2 = sheet.createRow(3);
            String[] example2 = {"", "", "", "李四", "20260002", "lisi@example.com", "13900139000", ""};
            for (int i = 0; i < example2.length; i++) {
                exampleRow2.createCell(i).setCellValue(example2[i]);
            }

            sheet.setColumnWidth(0, 6000);
            sheet.setColumnWidth(1, 8000);
            sheet.setColumnWidth(2, 6000);
            sheet.setColumnWidth(3, 6000);
            sheet.setColumnWidth(4, 6000);
            sheet.setColumnWidth(5, 8000);
            sheet.setColumnWidth(6, 6000);
            sheet.setColumnWidth(7, 8000);

            workbook.write(out);
            return out.toByteArray();
        } catch (Exception e) {
            log.error("Failed to build Excel template: {}", e.getMessage());
            throw new RuntimeException("生成Excel模板失败", e);
        }
    }
}
