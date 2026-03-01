package com.sirius.s3client.auth;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.google.android.material.textfield.TextInputEditText;
import com.google.android.material.textfield.TextInputLayout;
import com.sirius.s3client.API.ApiClient;
import com.sirius.s3client.API.ApiService;
import com.sirius.s3client.R;
import com.sirius.s3client.activities.AuthActivity;
import com.sirius.s3client.request.RegisterRequest;
import com.sirius.s3client.response.RegisterResponse;
import java.io.IOException;
import java.util.Objects;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class RegisterFragment extends BaseAuthFragment {
    private TextInputLayout ilEmail, ilPassword, ilPasswordConfirm;
    private TextInputEditText etEmail, etPassword, etPasswordConfirm;
    private Button btnRegister, btnSignIn;
    private ApiService apiService;



    private void initViews(View view){
        this.ilEmail = view.findViewById(R.id.il_email);
        this.ilPassword = view.findViewById(R.id.il_password);
        this.ilPasswordConfirm = view.findViewById(R.id.il_password_confirm);


        if (ilEmail == null) throw new IllegalStateException("il_email not found");
        if (ilPassword == null) throw new IllegalStateException("il_password not found");
        if (ilPasswordConfirm == null) throw new IllegalStateException("il_password_confirm not found");

        if(this.ilEmail.getEditText()!=null){
            this.etEmail = (TextInputEditText) ilEmail.getEditText();
        } else {
            throw new IllegalStateException("No EditText inside il_email");
        }

        if (this.ilPassword.getEditText()!=null){
            this.etPassword = (TextInputEditText) ilPassword.getEditText();
        } else {
            throw new IllegalStateException("No EditText inside il_password");
        }

        if(this.ilPasswordConfirm.getEditText()!=null){
            this.etPasswordConfirm = (TextInputEditText) ilPasswordConfirm.getEditText();
        } else {
            throw new IllegalStateException("No EditText inside il_password_confirm");
        }

        this.btnRegister = view.findViewById(R.id.btn_register);
        this.btnSignIn = view.findViewById(R.id.btn_sign_in);
    }

    private void setOnClickListeners(){
        btnRegister.setOnClickListener(v -> performRegister());
        btnSignIn.setOnClickListener(v -> ((AuthActivity) requireActivity()).navigateToLogin());
    }

    private boolean validateEmail(String email) {
        return checkAuthField(ilEmail, AuthValidator.validateEmail(email));
    }
    private boolean validatePassword(String password, String passwordConfirm){
        return checkAuthField(ilPassword, AuthValidator.validatePassword(password)) && checkAuthField(ilPasswordConfirm, AuthValidator.validatePassword(passwordConfirm)) && checkAuthField(ilPasswordConfirm, AuthValidator.validatePasswordConfirm(password, passwordConfirm));
    }


    private void performRegister() {
        String email = Objects.requireNonNull(etEmail.getText()).toString().trim();
        String password = Objects.requireNonNull(etPassword.getText()).toString();
        String passwordConfirm = Objects.requireNonNull(etPasswordConfirm.getText()).toString();

        if (!validateEmail(email) || !validatePassword(password, passwordConfirm)) {
            return;
        }

        btnRegister.setEnabled(false);
        btnSignIn.setEnabled(false);

        RegisterRequest request = new RegisterRequest(email, password);
        apiService.register(request).enqueue(new Callback<>() {
            @Override
            public void onResponse(@NonNull Call<RegisterResponse> call, @NonNull Response<RegisterResponse> response) {
                btnRegister.setEnabled(true);
                btnSignIn.setEnabled(true);

                if (response.isSuccessful()) {
                    Toast.makeText(getContext(), "Registration successful! Please log in.", Toast.LENGTH_LONG).show();
                    ((AuthActivity) requireActivity()).navigateToLogin();
                } else {
                    String errorMsg = "Registration failed";
                    try {
                        if (response.errorBody() != null) {
                            errorMsg = response.errorBody().string();
                        }
                    } catch (IOException ignored) {}
                    Toast.makeText(getContext(), errorMsg, Toast.LENGTH_LONG).show();
                }
            }

            @Override
            public void onFailure(@NonNull Call<RegisterResponse> call, @NonNull Throwable t) {
                btnRegister.setEnabled(true);
                btnSignIn.setEnabled(true);
                Toast.makeText(getContext(), "Network error: " + t.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState){
        View view = inflater.inflate(R.layout.fragment_register, container, false);
        initViews(view);
        setOnClickListeners();
        apiService = ApiClient.getInstance(requireContext()).getApiService();
        return view;
    }
}
