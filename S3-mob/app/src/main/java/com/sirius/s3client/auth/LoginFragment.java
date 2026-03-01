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
import com.sirius.s3client.activities.AuthActivity;
import com.sirius.s3client.R;
import com.sirius.s3client.request.LoginRequest;
import com.sirius.s3client.response.LoginResponse;
import com.sirius.s3client.security.SecurePrefs;

import java.io.IOException;
import java.util.Objects;

import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class LoginFragment extends BaseAuthFragment {
    private TextInputLayout ilEmail, ilPassword;
    private TextInputEditText etEmail, etPassword;
    private Button btnLogin, btnSignUp;

    private ApiService apiService;
    private SecurePrefs securePrefs;

    private void initViews(View view){
        this.ilEmail =  view.findViewById(R.id.il_email);
        this.ilPassword = view.findViewById(R.id.il_password);

        if (ilEmail == null) throw new IllegalStateException("il_email not found");
        if (ilPassword == null) throw new IllegalStateException("il_password not found");

        if (this.ilEmail.getEditText() != null){
            this.etEmail = (TextInputEditText) this.ilEmail.getEditText();
        } else {
            throw new IllegalStateException("No EditText inside il_email");
        }

        if (this.ilPassword.getEditText() != null){
            this.etPassword = (TextInputEditText) this.ilPassword.getEditText();
        } else {
            throw new IllegalStateException("No EditText inside il_password");
        }

        this.btnLogin = view.findViewById(R.id.btn_login);
        this.btnSignUp = view.findViewById(R.id.btn_signup);
    }

    private void setOnClickListeners(){
        btnLogin.setOnClickListener(v -> performLogin());
        btnSignUp.setOnClickListener(v -> ((AuthActivity) requireActivity()).navigateToRegister());
    }

    private boolean validateEmail(String email) {
        return checkAuthField(ilEmail, AuthValidator.validateEmail(email));
    }
    private boolean validatePassword(String password){
        return checkAuthField(ilPassword, AuthValidator.validatePasswordShort(password));
    }


    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState){
        View view = inflater.inflate(R.layout.fragment_login, container, false);
        initViews(view);
        setOnClickListeners();
        apiService = ApiClient.getInstance(requireContext()).getApiService();
        securePrefs = new SecurePrefs(requireContext());
        return view;
    }

    private void performLogin() {
        String email = Objects.requireNonNull(etEmail.getText()).toString().trim();
        String password = Objects.requireNonNull(etPassword.getText()).toString();

        if (!validateEmail(email) || !validatePassword(password)) {
            return;
        }

        btnLogin.setEnabled(false);
        btnSignUp.setEnabled(false);

        LoginRequest request = new LoginRequest(email, password);
        apiService.login(request).enqueue(new Callback<>() {
            @Override
            public void onResponse(@NonNull Call<LoginResponse> call, @NonNull Response<LoginResponse> response) {
                btnLogin.setEnabled(true);
                btnSignUp.setEnabled(true);

                if (response.isSuccessful() && response.body() != null) {
                    LoginResponse loginResp = response.body();
                    securePrefs.saveTokens(loginResp.getSessionToken(), loginResp.getCsrfToken());
                    ((AuthActivity) requireActivity()).goToMainActivity();
                } else {
                    String errorMsg = "Login failed";
                    try {
                        if (response.errorBody() != null) {
                            errorMsg = response.errorBody().string();
                        }
                    } catch (IOException ignored) {}
                    Toast.makeText(getContext(), errorMsg, Toast.LENGTH_LONG).show();
                }
            }

            @Override
            public void onFailure(@NonNull Call<LoginResponse> call, @NonNull Throwable t) {
                btnLogin.setEnabled(true);
                btnSignUp.setEnabled(true);
                Toast.makeText(getContext(), "Network error: " + t.getMessage(), Toast.LENGTH_LONG).show();
            }
        });
    }
}
