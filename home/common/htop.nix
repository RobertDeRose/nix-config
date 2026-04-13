# home/common/htop.nix
# Cross-platform htop configuration.
{ config, ... }:
{
  programs.htop = {
    enable = true;
    settings = {
      hide_kernel_threads = true;
      hide_userland_threads = false;
      hide_running_in_container = false;
      shadow_other_users = false;
      show_thread_names = false;
      show_program_path = true;
      highlight_base_name = false;
      highlight_deleted_exe = true;
      shadow_distribution_path_prefix = false;
      highlight_megabytes = true;
      highlight_threads = true;
      highlight_changes = false;
      highlight_changes_delay_secs = 5;
      find_comm_in_cmdline = true;
      strip_exe_from_cmdline = true;
      show_merged_command = false;
      header_margin = true;
      screen_tabs = true;
      detailed_cpu_time = false;
      cpu_count_from_one = false;
      show_cpu_usage = true;
      show_cpu_frequency = false;
      show_cached_memory = true;
      update_process_names = false;
      account_guest_in_cpu_meter = false;
      color_scheme = 0;
      enable_mouse = true;
      delay = 15;
      hide_function_bar = 0;
      header_layout = "two_50_50";
      fields = with config.lib.htop.fields; [
        PID
        USER
        PRIORITY
        NICE
        M_VIRT
        M_RESIDENT
        STATE
        PERCENT_CPU
        PERCENT_MEM
        TIME
        COMM
      ];
    }
    // (
      with config.lib.htop;
      leftMeters [
        (bar "LeftCPUs2")
        (bar "Memory")
        (bar "Swap")
      ]
    )
    // (
      with config.lib.htop;
      rightMeters [
        (bar "RightCPUs2")
        (text "Tasks")
        (text "LoadAverage")
        (text "Uptime")
      ]
    );
  };
}
