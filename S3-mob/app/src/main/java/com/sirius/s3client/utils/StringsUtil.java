package com.sirius.s3client.utils;

public class StringsUtil {
    public static boolean hasUpperCase(String password) {
        return password != null && password.matches(".*[A-Z].*");
    }

    public static boolean hasLowerCase(String password) {
        return password != null && password.matches(".*[a-z].*");
    }

    public static boolean hasDigit(String password) {
        return password != null && password.matches(".*[0-9].*");
    }

    public static boolean hasSpecialChar(String password) {
        return password != null && password.matches(".*[!@#$%*].*");
    }
}
