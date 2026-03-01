package com.sirius.s3client.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.PopupMenu;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import com.sirius.s3client.R;
import com.sirius.s3client.dataModel.FileItem;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class ObjectsAdapter extends RecyclerView.Adapter<ObjectsAdapter.ViewHolder> {
    private List<FileItem> items;
    private final OnObjectActionListener listener;

    public void setItems(List<FileItem> files) {
        this.items  = files;
    }

    public interface OnObjectActionListener {
        void onObjectClick(FileItem item);
        void onObjectDownload(FileItem item);
        void onObjectDelete(FileItem item);
        void onObjectShare(FileItem item);
        void onObjectMove(FileItem item);
    }

    public ObjectsAdapter(List<FileItem> items, OnObjectActionListener listener) {
        this.items = items;
        this.listener = listener;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_object, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        FileItem item = items.get(position);
        holder.tvName.setText(item.getName());
        if (item.isFolder()) {
            holder.ivIcon.setImageResource(R.drawable.ic_folder);
            holder.tvDetails.setVisibility(View.GONE);
        } else {
            if (item.getMimeType() != null && item.getMimeType().startsWith("image/")) {
                Glide.with(holder.itemView.getContext())
                        .load(item.getPath())
                        .placeholder(R.drawable.ic_file)
                        .into(holder.ivIcon);
            } else {
                holder.ivIcon.setImageResource(R.drawable.ic_file);
            }
            holder.tvDetails.setVisibility(View.VISIBLE);
            holder.tvDetails.setText(item.getFormattedSize() + " • " + formatDate(item.getModifiedAt()));
        }
        holder.itemView.setOnClickListener(v -> {
            if (listener != null) listener.onObjectClick(item);
        });
        holder.ivMore.setOnClickListener(v -> showPopupMenu(v, item));
    }

    @Override
    public int getItemCount() { return items.size(); }

    private void showPopupMenu(View anchor, FileItem item) {
        PopupMenu popup = new PopupMenu(anchor.getContext(), anchor);
        popup.getMenuInflater().inflate(R.menu.menu_object, popup.getMenu());
        popup.setOnMenuItemClickListener(menuItem -> {
            int id = menuItem.getItemId();
            if (id == R.id.action_download && listener != null && !item.isFolder()) {
                listener.onObjectDownload(item);
                return true;
            } else if (id == R.id.action_delete && listener != null) {
                listener.onObjectDelete(item);
                return true;
            } else if (id == R.id.action_share && listener != null) {
                listener.onObjectShare(item);
                return true;
            } else if (id == R.id.action_move && listener != null) {
                listener.onObjectMove(item);
                return true;
            }
            return false;
        });
        popup.show();
    }

    private String formatDate(String dateStr) {
        try {
            SimpleDateFormat input = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US);
            SimpleDateFormat output = new SimpleDateFormat("dd MMM yyyy", Locale.getDefault());
            Date date = input.parse(dateStr);
            assert date != null;
            return output.format(date);
        } catch (Exception e) {
            return dateStr;
        }
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        ImageView ivIcon, ivMore;
        TextView tvName, tvDetails;
        ViewHolder(@NonNull View itemView) {
            super(itemView);
            ivIcon = itemView.findViewById(R.id.iv_object_icon);
            tvName = itemView.findViewById(R.id.tv_object_name);
            tvDetails = itemView.findViewById(R.id.tv_object_details);
            ivMore = itemView.findViewById(R.id.iv_object_more);
        }
    }
}