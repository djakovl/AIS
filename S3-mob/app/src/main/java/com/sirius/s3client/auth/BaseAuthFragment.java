package com.sirius.s3client.auth;

import androidx.fragment.app.Fragment;

import com.google.android.material.textfield.TextInputLayout;

public class BaseAuthFragment extends Fragment {
    protected void createTextInputLayoutMessageError(TextInputLayout textInputLayout, String message){
        textInputLayout.setError(message);
        if(textInputLayout.getEditText() != null){
            textInputLayout.getEditText().requestFocus();
        }
    }

    protected boolean checkAuthField(TextInputLayout textInputLayout, int errCode){
        if(errCode != AuthValidator.NO_ERROR){
            createTextInputLayoutMessageError(textInputLayout, getString(errCode));
            return false;
        }

        textInputLayout.setError(null);
        return true;
    }
}
