package com.sirius.s3client.auth;

import static com.sirius.s3client.utils.StringsUtil.*;

import android.util.Patterns;

import com.sirius.s3client.R;

public class AuthValidator {
    public static final int NO_ERROR = -1;
    public static int validateEmail(String email){
        if (email.isEmpty()) {
            return R.string.email_empty;
        }

        if (!Patterns.EMAIL_ADDRESS.matcher(email).matches()) {
            return R.string.invalid_email;
        }

        return NO_ERROR;
    }

    public static int validatePasswordShort(String password){
        if(password.isEmpty()){
            return R.string.empty_password;
        }

        if(password.length() < 12){
            return R.string.short_password;
        }

        return NO_ERROR;
    }

    public static int validatePasswordConfirm(String password, String passwordConf){
        if(!password.equals(passwordConf)){
            return R.string.passwords_mismatch;
        }

        return NO_ERROR;
    }

    public static int validatePassword(String password){
        int shortCheck = validatePasswordShort(password);
        if (shortCheck != NO_ERROR){
            return shortCheck;
        }

        if(!hasUpperCase(password)){
            return R.string.big_letter;
        }

        if(!hasLowerCase(password)){
            return R.string.small_letter;
        }

        if(!hasDigit(password)){
            return R.string.need_number;
        }

        if(!hasSpecialChar(password)){
            return R.string.need_special_char;
        }

        return NO_ERROR;
    }
}
