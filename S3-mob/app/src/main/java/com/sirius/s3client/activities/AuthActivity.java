package com.sirius.s3client.activities;

import android.content.Intent;
import android.os.Bundle;

import androidx.activity.EdgeToEdge;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentTransaction;

import com.sirius.s3client.R;
import com.sirius.s3client.auth.LoginFragment;
import com.sirius.s3client.auth.RegisterFragment;

public class AuthActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EdgeToEdge.enable(this);
        setContentView(R.layout.activity_auth);

        if (savedInstanceState == null) {
            showLoginFragment();
        }
    }

    private void showLoginFragment() {
        FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
        fragmentTransaction.replace(R.id.auth_container, new LoginFragment());
        fragmentTransaction.commit();
    }

    private void replaceFragment(Fragment fragment){
        Fragment currentFragment = getSupportFragmentManager().findFragmentById(R.id.auth_container);
        if (currentFragment != null && currentFragment.getClass().equals(fragment.getClass())){
            return;
        }

        getSupportFragmentManager().beginTransaction()
                .setReorderingAllowed(true)
                .replace(R.id.auth_container, fragment)
                .commit();
    }

    public void navigateToLogin() {
        replaceFragment(new LoginFragment());
    }

    public void navigateToRegister() {
        replaceFragment(new RegisterFragment());
    }

    public void goToMainActivity(){
        startActivity(new Intent(this, MainActivity.class));
    }
}