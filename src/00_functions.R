# Shared utility functions for microbiome analysis

# ---- Plot Theme ----

theme_micro <- function(base_size = 12) {
    theme_minimal(base_size = base_size) +
        theme(
            axis.text.x = element_text(angle = 30, hjust = 1),
            strip.text = element_text(face = "bold", size = base_size * 1.1),
            plot.title = element_text(face = "bold", size = base_size * 1.2),
            axis.title = element_text(face = "bold"),
            axis.title.x = element_text(face = "bold"),
            panel.spacing = unit(0.6, "lines"),
            panel.grid.minor = element_blank()
        )
}


# ---- Taxa Cleaning Helpers ----

clean_tax <- function(x) sub("^[a-z]__", "", x)

make_taxa_long <- function(df, tax_col, meta_cols, value_col = "Value") {
    df |>
        tidyr::pivot_longer(
            -dplyr::all_of(meta_cols),
            names_to = tax_col,
            values_to = value_col
        ) |>
        dplyr::mutate(
            !!tax_col := clean_tax(.data[[tax_col]])
        )
}


# ---- Sample Removal Helpers ----

calc_na_prop_abund <- function(df, level_name) {
    df |>
        mutate(is_na = is.na(.data[[level_name]]) | .data[[level_name]] == "NA") |>
        group_by(Sample_ID) |>
        summarise(
            prop_na = sum(Value[is_na], na.rm = TRUE) / sum(Value, na.rm = TRUE),
            .groups = "drop"
        ) |>
        mutate(Taxonomic_Level = level_name)
}

find_high_na <- function(df, level_name, threshold = 0.9) {
    df |>
        mutate(is_na = is.na(.data[[level_name]]) | .data[[level_name]] == "NA") |>
        group_by(Sample_ID) |>
        summarise(
            prop_na = sum(Value[is_na], na.rm = TRUE) / sum(Value, na.rm = TRUE),
            .groups = "drop"
        ) |>
        filter(prop_na > threshold) |>
        mutate(Taxonomic_Level = level_name)
}

removal <- function(df, vector) {
    df |> filter(!(Sample_ID %in% vector))
}


# ---- Relative Abundance Plot Helpers ----

plot_top_taxa <- function(data, tax_col, n_top = 10) {
    # Data may already be normalized (sum to 100% per Sample_ID)
    # But will keep Rel_abund in, in case non-normalized dta is ever entered
    data_norm <- data |>
        dplyr::group_by(Sample_ID) |>
        dplyr::mutate(Rel_abund = Value / sum(Value, na.rm = TRUE)) |>
        dplyr::ungroup()

    top_taxa <- data_norm |>
        dplyr::group_by(.data[[tax_col]]) |>
        dplyr::summarise(mean_abund = mean(Rel_abund, na.rm = TRUE), .groups = "drop") |>
        dplyr::arrange(dplyr::desc(mean_abund)) |>
        dplyr::slice_head(n = n_top) |>
        dplyr::pull(.data[[tax_col]])

    plot_df <- data_norm |>
        dplyr::mutate(
            tax_plot = dplyr::if_else(.data[[tax_col]] %in% top_taxa,
                .data[[tax_col]],
                "Other"
            )
        ) |>
        dplyr::group_by(Sample_ID, Study_group_new, tax_plot) |>
        dplyr::summarise(Rel_abund = sum(Rel_abund, na.rm = TRUE), .groups = "drop") |>
        dplyr::group_by(Study_group_new, tax_plot) |>
        dplyr::summarise(mean_abund = mean(Rel_abund, na.rm = TRUE), .groups = "drop")

    tax_order <- plot_df |>
        dplyr::group_by(tax_plot) |>
        dplyr::summarise(total_abund = mean(mean_abund), .groups = "drop") |>
        dplyr::arrange(desc(total_abund)) |>
        dplyr::pull(tax_plot)

    plot_df <- plot_df |>
        mutate(tax_plot = factor(tax_plot, levels = tax_order))

    ggplot2::ggplot(
        plot_df,
        ggplot2::aes(x = Study_group_new, y = mean_abund, fill = tax_plot)
    ) +
        ggplot2::geom_col() +
        ggplot2::labs(fill = tax_col) +
        ggplot2::coord_cartesian(ylim = c(0, 1)) +
        ggplot2::scale_y_continuous(
            expand = ggplot2::expansion(mult = c(0, 0.02))
        ) +
        theme_micro()
}


# ---- Heatmap Helpers ----

make_taxa_matrix <- function(df, tax_col, sample_col = "Sample_ID",
                             value_col = "Value", pseudocount = 1e-6) {
    mat <- df |>
        filter(!is.na(.data[[tax_col]]), .data[[tax_col]] != "NA") |>
        group_by(.data[[tax_col]], .data[[sample_col]]) |>
        summarise(abund = sum(.data[[value_col]], na.rm = TRUE), .groups = "drop") |>
        pivot_wider(
            names_from = all_of(sample_col),
            values_from = abund,
            values_fill = 0
        ) |>
        column_to_rownames(tax_col) |>
        as.matrix()

    mat <- mat[rowSums(mat, na.rm = TRUE) > 0, , drop = FALSE]
    mat <- mat[apply(mat, 1, sd, na.rm = TRUE) > 0, , drop = FALSE]
    min_prev <- ceiling(0.10 * ncol(mat))
    mat <- mat[rowSums(mat > 0, na.rm = TRUE) >= min_prev, , drop = FALSE]

    log_mat <- log10(mat + pseudocount)
    z <- t(scale(t(log_mat)))
    z[!is.finite(z)] <- 0
    return(z)
}

plot_taxa_heatmap <- function(z_mat,
                              meta_data,
                              sample_col = "Sample_ID",
                              group_col = "Study_group_new",
                              row_label = "Fungal Family",
                              study_colors = c(
                                  "Non-IBD" = "#4E79A7",
                                  "Active IBD" = "#F28E2B",
                                  "Quiescent" = "#59A14F"
                              )) {
    annotation_col <- meta_data |>
        select(all_of(c(sample_col, group_col))) |>
        distinct() |>
        filter(.data[[sample_col]] %in% colnames(z_mat)) |>
        column_to_rownames(sample_col)

    annotation_col <- annotation_col[colnames(z_mat), , drop = FALSE]

    ha <- HeatmapAnnotation(
        `Study Group` = annotation_col[[group_col]],
        col = list(`Study Group` = study_colors),
        annotation_name_gp = gpar(fontface = "bold", fontsize = 14),
        annotation_legend_param = list(
            `Study Group` = list(
                title_position = "topcenter",
                direction = "horizontal",
                nrow = 1
            )
        )
    )

    ht <- Heatmap(
        z_mat,
        name = "Z-score",
        row_title = row_label,
        row_title_gp = gpar(fontface = "bold", fontsize = 14),
        row_names_gp = gpar(fontsize = 10),
        column_names_gp = gpar(fontsize = 10),
        column_title = "Sample ID",
        column_title_gp = gpar(fontface = "bold", fontsize = 14),
        top_annotation = ha,
        cluster_rows = TRUE,
        cluster_columns = TRUE,
        show_row_names = TRUE,
        show_column_names = TRUE,
        column_names_rot = 60,
        heatmap_legend_param = list(
            title_position = "topcenter",
            direction = "horizontal"
        )
    )

    draw(
        ht,
        heatmap_legend_side = "bottom",
        annotation_legend_side = "bottom"
    )
}
