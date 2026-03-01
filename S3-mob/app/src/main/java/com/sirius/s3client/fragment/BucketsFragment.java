package com.sirius.s3client.fragment;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.textfield.TextInputEditText;
import com.sirius.s3client.R;
import com.sirius.s3client.adapter.BucketsAdapter;
import com.sirius.s3client.dataModel.Bucket;
import com.sirius.s3client.viewModel.BucketsViewModel;

import java.util.Objects;

public class BucketsFragment extends Fragment implements BucketsAdapter.OnBucketActionListener {
    private BucketsViewModel viewModel;
    private BucketsAdapter adapter;
    private RecyclerView recyclerView;
    private FloatingActionButton fabAdd;
    private View progressBar, emptyView;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_buckets, container, false);
        recyclerView = view.findViewById(R.id.recycler_view_buckets);
        fabAdd = view.findViewById(R.id.fab_add_bucket);
        progressBar = view.findViewById(R.id.progress_bar);
        emptyView = view.findViewById(R.id.tv_empty);
        return view;
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setupRecyclerView();
        setupViewModel();
        fabAdd.setOnClickListener(v -> showCreateBucketDialog());
        viewModel.loadBuckets();
    }

    private void setupRecyclerView() {
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        adapter = new BucketsAdapter(null, this);
        recyclerView.setAdapter(adapter);
    }

    private void setupViewModel() {
        viewModel = new ViewModelProvider(this).get(BucketsViewModel.class);
        viewModel.getBuckets().observe(getViewLifecycleOwner(), buckets -> {
            adapter.setBuckets(buckets);
            emptyView.setVisibility(buckets == null || buckets.isEmpty() ? View.VISIBLE : View.GONE);
        });
        viewModel.getError().observe(getViewLifecycleOwner(), error -> {
            if (error != null) Toast.makeText(requireContext(), error, Toast.LENGTH_LONG).show();
        });
        viewModel.getLoading().observe(getViewLifecycleOwner(), isLoading -> {
            progressBar.setVisibility(isLoading ? View.VISIBLE : View.GONE);
        });
        viewModel.getOperationSuccess().observe(getViewLifecycleOwner(), success -> {
            if (success) {
                viewModel.loadBuckets();
                viewModel.resetOperationSuccess();
            }
        });
    }

    private void showCreateBucketDialog() {
        View dialogView = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_create_bucket, null);
        TextInputEditText etName = dialogView.findViewById(R.id.et_bucket_name);
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle(R.string.create_bucket)
                .setView(dialogView)
                .setPositiveButton(R.string.create, (dialog, which) -> {
                    String name = Objects.requireNonNull(etName.getText()).toString().trim();
                    if (!name.isEmpty()) {
                        viewModel.createBucket(name);
                    } else {
                        Toast.makeText(requireContext(), R.string.name_required, Toast.LENGTH_SHORT).show();
                    }
                })
                .setNegativeButton(R.string.cancel, null)
                .show();
    }

    @Override
    public void onBucketClick(Bucket bucket) {
        ObjectsFragment fragment = ObjectsFragment.newInstance(bucket.getId());
        requireActivity().getSupportFragmentManager().beginTransaction()
                .replace(R.id.fragment_container, fragment)
                .addToBackStack(null)
                .commit();
    }

    @Override
    public void onBucketDelete(Bucket bucket) {
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle(R.string.delete_bucket)
                .setMessage(getString(R.string.delete_bucket_confirm, bucket.getName()))
                .setPositiveButton(R.string.delete, (dialog, which) -> viewModel.deleteBucket(bucket.getId()))
                .setNegativeButton(R.string.cancel, null)
                .show();
    }

    @Override
    public void onBucketShare(Bucket bucket) {
        Toast.makeText(requireContext(), "Share not implemented", Toast.LENGTH_SHORT).show();
    }
}