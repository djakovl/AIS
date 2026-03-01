package com.sirius.s3client.fragment;

import android.content.Context;
import android.net.Uri;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.chip.Chip;
import com.google.android.material.chip.ChipGroup;
import com.google.android.material.dialog.MaterialAlertDialogBuilder;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.textfield.TextInputEditText;
import com.sirius.s3client.R;
import com.sirius.s3client.adapter.ObjectsAdapter;
import com.sirius.s3client.dataModel.FileItem;
import com.sirius.s3client.response.ShareLinkResponse;
import com.sirius.s3client.viewModel.ObjectsViewModel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.Objects;

import okhttp3.ResponseBody;

public class ObjectsFragment extends Fragment implements ObjectsAdapter.OnObjectActionListener {
    private static final String ARG_BUCKET_ID = "bucket_id";
    private ObjectsViewModel viewModel;
    private ObjectsAdapter adapter;
    private RecyclerView recyclerView;
    private FloatingActionButton fabUpload, fabCreateFolder;
    private ChipGroup breadcrumbGroup;
    private View progressBar, emptyView;
    private String bucketId;

    private final ActivityResultLauncher<String> filePickerLauncher = registerForActivityResult(
            new ActivityResultContracts.GetContent(),
            uri -> {
                if (uri != null) {
                    handleSelectedFile(uri);
                }
            });

    public static ObjectsFragment newInstance(String bucketId) {
        Bundle args = new Bundle();
        args.putString(ARG_BUCKET_ID, bucketId);
        ObjectsFragment fragment = new ObjectsFragment();
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getArguments() != null) {
            bucketId = getArguments().getString(ARG_BUCKET_ID);
        }
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_objects, container, false);
        recyclerView = view.findViewById(R.id.recycler_view_objects);
        fabUpload = view.findViewById(R.id.fab_upload);
        fabCreateFolder = view.findViewById(R.id.fab_create_folder);
        breadcrumbGroup = view.findViewById(R.id.breadcrumb_chip_group);
        progressBar = view.findViewById(R.id.progress_bar);
        emptyView = view.findViewById(R.id.tv_empty);
        return view;
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setupRecyclerView();
        setupViewModel();
        setupFabs();
        viewModel.setBucketId(bucketId);
        viewModel.loadFiles("");
    }

    private void setupRecyclerView() {
        recyclerView.setLayoutManager(new LinearLayoutManager(requireContext()));
        adapter = new ObjectsAdapter(new ArrayList<>(), this);
        recyclerView.setAdapter(adapter);
    }

    private void setupViewModel() {
        viewModel = new ViewModelProvider(this).get(ObjectsViewModel.class);
        viewModel.getFiles().observe(getViewLifecycleOwner(), files -> {
            adapter.setItems(files);
            emptyView.setVisibility(files == null || files.isEmpty() ? View.VISIBLE : View.GONE);
            updateBreadcrumb(viewModel.getCurrentPath().getValue());
        });
        viewModel.getCurrentPath().observe(getViewLifecycleOwner(), this::updateBreadcrumb);
        viewModel.getError().observe(getViewLifecycleOwner(), error -> {
            if (error != null) Toast.makeText(requireContext(), error, Toast.LENGTH_LONG).show();
        });
        viewModel.getLoading().observe(getViewLifecycleOwner(), isLoading -> {
            progressBar.setVisibility(isLoading ? View.VISIBLE : View.GONE);
        });
        viewModel.getOperationSuccess().observe(getViewLifecycleOwner(), success -> {
            if (success) {
                viewModel.loadFiles(viewModel.getCurrentPath().getValue());
                viewModel.resetOperationSuccess();
            }
        });
        viewModel.getUploadedFile().observe(getViewLifecycleOwner(), file -> {
            if (file != null) {
                Toast.makeText(requireContext(), "Uploaded: " + file.getName(), Toast.LENGTH_SHORT).show();
            }
        });
        viewModel.getDownloadedFile().observe(getViewLifecycleOwner(), body -> {
            if (body != null) {
                saveDownloadedFile(body);
                viewModel.clearDownloadedFile();
            }
        });
        viewModel.getShareLink().observe(getViewLifecycleOwner(), link -> {
            if (link != null) {
                showShareLinkDialog(link);
                viewModel.clearShareLink();
            }
        });
    }

    private void setupFabs() {
        fabUpload.setOnClickListener(v -> {
            if (fabCreateFolder.getVisibility() == View.GONE) {
                fabCreateFolder.show();
            } else {
                fabCreateFolder.hide();
            }
        });

        fabCreateFolder.setOnClickListener(v -> showCreateFolderDialog());
    }

    private void updateBreadcrumb(String path) {
        breadcrumbGroup.removeAllViews();
        if (path == null || path.isEmpty()) {
            // Root: show "Root" chip
            Chip chip = new Chip(requireContext());
            chip.setText("Root");
            chip.setClickable(false);
            breadcrumbGroup.addView(chip);
            return;
        }
        String[] parts = path.split("/");
        StringBuilder current = new StringBuilder();
        for (String part : parts) {
            if (part.isEmpty()) continue;
            if (current.length() > 0) current.append("/");
            current.append(part);
            Chip chip = new Chip(requireContext());
            chip.setText(part);
            chip.setTag(current.toString());
            chip.setOnClickListener(v -> {
                String targetPath = (String) v.getTag();
                viewModel.loadFiles(targetPath);
            });
            breadcrumbGroup.addView(chip);
        }
    }

    private void showCreateFolderDialog() {
        View dialogView = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_create_folder, null);
        TextInputEditText etName = dialogView.findViewById(R.id.et_folder_name);
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle(R.string.create_folder)
                .setView(dialogView)
                .setPositiveButton(R.string.create, (dialog, which) -> {
                    String name = Objects.requireNonNull(etName.getText()).toString().trim();
                    if (!name.isEmpty()) {
                        viewModel.createFolder(name);
                    } else {
                        Toast.makeText(requireContext(), R.string.name_required, Toast.LENGTH_SHORT).show();
                    }
                })
                .setNegativeButton(R.string.cancel, null)
                .show();
    }

    private void showUploadDialog() {
        filePickerLauncher.launch("*/*"); // Allow any file type
    }

    private void handleSelectedFile(Uri uri) {
        File tempFile = null;
        try {
            InputStream inputStream = requireContext().getContentResolver().openInputStream(uri);
            if (inputStream != null) {
                tempFile = new File(requireContext().getCacheDir(), "upload_" + System.currentTimeMillis());
                OutputStream outputStream = new FileOutputStream(tempFile);
                byte[] buffer = new byte[4096];
                int bytesRead;
                while ((bytesRead = inputStream.read(buffer)) != -1) {
                    outputStream.write(buffer, 0, bytesRead);
                }
                outputStream.close();
                inputStream.close();
                viewModel.uploadFile(tempFile);
            }
        } catch (IOException e) {
            Toast.makeText(requireContext(), "Failed to read file", Toast.LENGTH_SHORT).show();
        }
    }

    private void saveDownloadedFile(ResponseBody body) {
        try {
            File file = new File(requireContext().getExternalCacheDir(), "download_" + System.currentTimeMillis());
            FileOutputStream fos = new FileOutputStream(file);
            fos.write(body.bytes());
            fos.close();
            Toast.makeText(requireContext(), "Downloaded: " + file.getAbsolutePath(), Toast.LENGTH_SHORT).show();
        } catch (IOException e) {
            Toast.makeText(requireContext(), "Failed to save file", Toast.LENGTH_SHORT).show();
        }
    }

    private void showShareLinkDialog(ShareLinkResponse link) {
        View dialogView = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_share, null);
        TextInputEditText etLink = dialogView.findViewById(R.id.et_share_link);
        etLink.setText(link.getUrl());
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle(R.string.share_link)
                .setView(dialogView)
                .setPositiveButton(R.string.copy, (dialog, which) -> {
                    // Copy to clipboard
                    android.content.ClipboardManager clipboard = (android.content.ClipboardManager) requireContext().getSystemService(Context.CLIPBOARD_SERVICE);
                    android.content.ClipData clip = android.content.ClipData.newPlainText("Share Link", link.getUrl());
                    clipboard.setPrimaryClip(clip);
                    Toast.makeText(requireContext(), R.string.copied, Toast.LENGTH_SHORT).show();
                })
                .setNegativeButton(R.string.close, null)
                .show();
    }

    @Override
    public void onObjectClick(FileItem item) {
        if (item.isFolder()) {
            viewModel.loadFiles(item.getPath());
        } else {
            viewModel.downloadFile(item.getId());
        }
    }

    @Override
    public void onObjectDownload(FileItem item) {
        viewModel.downloadFile(item.getId());
    }

    @Override
    public void onObjectDelete(FileItem item) {
        new MaterialAlertDialogBuilder(requireContext())
                .setTitle(R.string.delete)
                .setMessage(getString(R.string.delete_confirm, item.getName()))
                .setPositiveButton(R.string.delete, (dialog, which) -> viewModel.deleteItem(item.getId()))
                .setNegativeButton(R.string.cancel, null)
                .show();
    }

    @Override
    public void onObjectShare(FileItem item) {
        viewModel.createShareLink(item.getId());
    }

    @Override
    public void onObjectMove(FileItem item) {
        Toast.makeText(requireContext(), "Move not implemented", Toast.LENGTH_SHORT).show();
    }
}