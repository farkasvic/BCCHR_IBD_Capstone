dashboard_head_tags <- function() {
  tags$head(
    tags$style(HTML("
      .dashboard-card {
        background: #ffffff;
        border: 1px solid #d9e2ec;
        border-radius: 12px;
        padding: 18px 20px;
        margin-bottom: 20px;
        box-shadow: 0 2px 8px rgba(15, 23, 42, 0.06);
      }
      .dashboard-card h4 {
        margin-top: 0;
        margin-bottom: 14px;
        font-weight: 600;
      }
      .control-sidebar {
        padding-right: 10px;
      }
      .control-sidebar .dashboard-card {
        position: sticky;
        top: 20px;
      }
      .dashboard-row {
        margin-bottom: 8px;
      }
      .dashboard-row:last-child {
        margin-bottom: 0;
      }
    "))
  )
}

dashboard_card <- function(title, ...) {
  div(
    class = "dashboard-card",
    h4(title),
    ...
  )
}
