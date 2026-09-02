package com.chronoflow.backend.util;

public class MaskingUtil {

    public static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) return phone;
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    public static String maskEmail(String email) {
        if (email == null || email.isEmpty()) return email;
        int atIdx = email.indexOf('@');
        if (atIdx <= 0) return email;
        String prefix = email.substring(0, 1);
        String domain = email.substring(atIdx);
        return prefix + "****" + domain;
    }

    public static String maskStudentId(String studentId) {
        if (studentId == null || studentId.length() < 5) return studentId;
        return studentId.substring(0, 2) + "****" + studentId.substring(studentId.length() - 2);
    }

    public static String maskName(String name) {
        if (name == null || name.length() <= 1) return name;
        return name.charAt(0) + "*".repeat(name.length() - 1);
    }
}
