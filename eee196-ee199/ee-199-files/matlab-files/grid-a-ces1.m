%% 1. Master Scenario Parameters & Global Setup
clc; clear; close all; format compact;
 
% --- Target Scenarios to Run ---
scenario_years = [2025, 2030, 2040, 2050];

% ========================================================================
%  Corresponding capacities for each year
%  Align values sequentially with [2025, 2030, 2040, 2050]
% ========================================================================
pdp_peak_demands_MW      = [13728, 18038, 29984, 48014]; 
target_solar_capacity_MW = [ 5331, 6986, 21106, 33042]; 
target_wind_capacity_MW  = [ 1327,  2607,  8107, 16107]; 
target_osw_capacity_MW = [0, 2000, 5300, 19500];
bess_capacity_MW         = [ 1572,  1572,  4867,  13418]; 
dependable_capacity_MW   = [16353, 17368, 19248, 25744]; 
 
% --- File Paths ---
base_dir  = 'D:\University of the Philippines\EE 199';
solar_dir = fullfile(base_dir, 'luzon', 'solar');  
wind_dir  = fullfile(base_dir, 'luzon', 'wind');  
osw_dir = fullfile(base_dir, 'luzon', 'luzon_osw');
load_file = fullfile(base_dir, 'Luzon Hourly Demand.csv');
 
% --- CREZ Parameters (Luzon, 13 zones) ---
crez_solar_capacities = [985, 651, 496, 1046, 536, 101, 926, 1070, 1109, 765, 811, 707, 486];
crez_wind_capacities  = [1280, 654, 544, 1047, 531, 356, 834, 1072, 1239, 752, 675, 708, 502];
w_solar = (crez_solar_capacities / sum(crez_solar_capacities))'; 
w_wind  = (crez_wind_capacities  / sum(crez_wind_capacities))';  

% --- OSW Parameters (Luzon, 2 zones) ---
osw_site_capacities = [5000, 3000];
w_osw = (osw_site_capacities/sum(osw_site_capacities));
 
% --- Global Constants ---
start_year     = 1985;
years          = 40;
hours_per_year = 8760;
total_hours    = years * hours_per_year;
n_crez         = 13; 
n_osw          = 2;

%% 2. Import Base Load Profile (Runs Once)
disp('Importing Base Load Profile...');
load_array = readmatrix(load_file, 'Range', 'B4386:Y4750');
raw_base_profile = load_array';
raw_base_profile = raw_base_profile(:); 

%% 3 & 4. Import 40 Years of CREZ Solar and Wind Data (Runs Once)
disp('Processing 40-year MERRA-2 Solar Profiles...');
solar_40yr_UTC = zeros(total_hours, 1);
for y = 1:years
    current_year = num2str(start_year + y - 1);
    csv_files = dir(fullfile(solar_dir, current_year, '*.csv'));
    names = {csv_files.name};
    nums = cellfun(@(x) str2double(regexp(x, '\d+', 'match', 'once')), names);
    [~, idx] = sort(nums); csv_files = csv_files(idx);
    
    crez_solar_matrix = zeros(hours_per_year, n_crez);
    for j = 1:n_crez
        temp_data = readmatrix(fullfile(solar_dir, current_year, csv_files(j).name), 'NumHeaderLines', 1);
        crez_solar_matrix(:, j) = temp_data(1:hours_per_year, 2);
    end
    solar_40yr_UTC((y - 1) * hours_per_year + 1 : y * hours_per_year) = crez_solar_matrix * w_solar;
end

disp('Processing 40-year MERRA-2 Wind Profiles...');
wind_40yr_UTC = zeros(total_hours, 1);
for y = 1:years
    current_year = num2str(start_year + y - 1);
    csv_files = dir(fullfile(wind_dir, current_year, '*.csv'));
    names = {csv_files.name};
    nums = cellfun(@(x) str2double(regexp(x, '\d+', 'match', 'once')), names);
    [~, idx] = sort(nums); csv_files = csv_files(idx);
    
    crez_wind_matrix = zeros(hours_per_year, n_crez);
    for j = 1:n_crez
        temp_data = readmatrix(fullfile(wind_dir, current_year, csv_files(j).name), 'NumHeaderLines', 1);
        crez_wind_matrix(:, j) = temp_data(1:hours_per_year, 2);
    end
    wind_40yr_UTC((y - 1) * hours_per_year + 1 : y * hours_per_year) = crez_wind_matrix * w_wind;
end

disp('Processing 40-year MERRA-2 Offshore Wind Profiles...');
osw_40yr_UTC = zeros(total_hours, 1);

for y = 1:years
    current_year = num2str(start_year + y - 1);
    
    csv_files = dir(fullfile(osw_dir, current_year, '*.csv'));
    names = {csv_files.name};
    nums = cellfun(@(x) str2double(regexp(x, '\d+', 'match', 'once')), names);
    [~, idx] = sort(nums); csv_files = csv_files(idx);
    
    crez_osw_matrix = zeros(hours_per_year, n_osw);
    for j = 1:n_osw
        temp_data = readmatrix(fullfile(osw_dir, current_year, csv_files(j).name), 'NumHeaderLines', 1);
        crez_osw_matrix(:, j) = temp_data(1:hours_per_year, 2);
    end
    
    osw_40yr_UTC((y - 1) * hours_per_year + 1 : y * hours_per_year) = crez_osw_matrix * w_osw';
end

% Apply UTC-to-PST shift once
solar_40yr_PST = circshift(solar_40yr_UTC, 8);
wind_40yr_PST  = circshift(wind_40yr_UTC,  8);
osw_40yr_PST = circshift(osw_40yr_UTC, 8);

% ========================================================================
%  MASTER SCENARIO LOOP
% ========================================================================
for s_idx = 1:length(scenario_years)
    target_year = scenario_years(s_idx);
    fprintf('\n======================================================\n');
    fprintf('STARTING RUN FOR SCENARIO YEAR: %d\n', target_year);
    fprintf('======================================================\n');
    
    % Extract parameters for the current loop year
    current_peak_load  = pdp_peak_demands_MW(s_idx);
    current_solar_cap  = target_solar_capacity_MW(s_idx);
    current_wind_cap   = target_wind_capacity_MW(s_idx);
    current_osw_cap    = target_osw_capacity_MW(s_idx);
    current_bess_cap   = bess_capacity_MW(s_idx);
    current_dependable = dependable_capacity_MW(s_idx);
    
    % Setup dedicated export folder for this year
    output_dir = sprintf('D:\\eee196-ee199\\ee-199-files\\matlab-files\\Results\\Luzon\\CES1\\%d', target_year);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    %% 5. Scale Data and Calculate Net Load
    disp('Scaling profiles and calculating Net Load...');
    
    % Scale load
    load_profile_scaled = (raw_base_profile / max(raw_base_profile)) * current_peak_load;
    load_40yr = repmat(load_profile_scaled, years, 1);
    
    % Scale renewables
    actual_solar_40yr_MW = solar_40yr_PST * current_solar_cap;
    actual_wind_40yr_MW  = wind_40yr_PST  * current_wind_cap;
    actual_osw_40yr_MW = osw_40yr_PST * current_osw_cap;
    
    % Calculate Net Load
    net_load_40yr_MW = load_40yr - actual_solar_40yr_MW - actual_wind_40yr_MW - actual_osw_40yr_MW;

    max_net_load_MW = max(net_load_40yr_MW);
    margin_MW = current_dependable - max_net_load_MW;
    
    fprintf('\n--- CAPACITY ADEQUACY CHECK (%d) ---\n', target_year);
    fprintf('Max Net Load Amplitude: %8.2f MW\n', max_net_load_MW);
    fprintf('Dependable Capacity:    %8.2f MW\n', current_dependable);
    
    if margin_MW < 0
        fprintf('STATUS: DEFICIT of      %8.2f MW (Max Load breached Dependable limit!)\n', abs(margin_MW));
    else
        fprintf('STATUS: SURPLUS of      %8.2f MW (Dependable limit safely covers Max Load)\n', margin_MW);
    end
    fprintf('------------------------------------\n\n');
    
    %% 6. Generate 40-Year Recurrence Matrix
    disp('Calculating Recurrence Matrix...');
    
    amplitude_step = 1;  
    amplitudes = floor(min(net_load_40yr_MW)):amplitude_step:ceil(max(net_load_40yr_MW));
    max_duration = 8760; 
    durations    = 1:max_duration;
    
    recurrence_matrix = zeros(length(amplitudes), length(durations));
    
    for i = 1:length(amplitudes)
        threshold = amplitudes(i);
        if threshold >= 0
            is_active = net_load_40yr_MW >= threshold; 
        else
            is_active = net_load_40yr_MW <= threshold;
        end
     
        diff_arr  = diff([0; is_active(:); 0]);
        start_idx = find(diff_arr ==  1);
        end_idx   = find(diff_arr == -1) - 1;
        event_durations = end_idx - start_idx + 1;
     
        if ~isempty(event_durations)
            event_durations(event_durations > max_duration) = max_duration;
            edges        = [durations, max_duration + 1];
            exact_counts = histcounts(event_durations, edges); 
            cumulative_counts = flip(cumsum(flip(exact_counts)));
            recurrence_matrix(i, :) = cumulative_counts;
        end
    end
         
%% 7. Data Preparation
    disp('Preparing Data for High-Speed Rendering...');
    heatmap_data = recurrence_matrix'; 
    heatmap_data(heatmap_data == 0) = NaN;  
    max_val = 100; 
    heatmap_data(heatmap_data > max_val) = max_val; 
    
    max_x_plotted = max(max(amplitudes), current_dependable);
    x_lim_target  = [min(amplitudes), max_x_plotted * 1.1];
    
%% 7A. PLOT 1: Short Duration View (144 Hours)
    fprintf('Rendering Plot 1 for %d...\n', target_year);
    fig1 = figure('Units', 'inches', 'Position', [1, 1, 16, 9.5], 'Color', 'w', 'Visible', 'off');
     
    % Convert to GW
    h1 = imagesc('XData', amplitudes / 1000, 'YData', durations, 'CData', heatmap_data);
    set(gca, 'YDir', 'normal'); 
    set(h1, 'AlphaData', ~isnan(heatmap_data)); 
    
    y_max_short = 144;
    ylim([1, y_max_short]);
    xlim(x_lim_target / 1000);
     
    colormap(turbo);
    ax1 = gca; ax1.Color = 'w'; ax1.FontSize = 24; ax1.FontName = 'Times New Roman';
    ax1.LineWidth = 1.5; ax1.TickDir = 'out'; ax1.XColor = 'k'; ax1.YColor = 'k'; 
    ax1.YTick = 0:48:y_max_short; 
    box on;
     
    clim([0, max_val]); 
    cb1 = colorbar; 
    cb1.LineWidth = 1.2; 
    cb1.Color = 'k'; 
    cb1.Ticks = 0:20:max_val; 
    cb1.FontSize = 24;
    
    tick_labels = cell(1, length(cb1.Ticks));
    for k = 1:length(cb1.Ticks)
        if cb1.Ticks(k) == max_val, tick_labels{k} = ['\ge ', num2str(cb1.Ticks(k))];
        else, tick_labels{k} = num2str(cb1.Ticks(k)); end
    end
    cb1.TickLabels = tick_labels;
    ylabel(cb1, 'Number of Occurrences', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    
    xlabel('Net Load Amplitude (GW)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    ylabel('Event Duration (Consecutive Hours)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    title_str = sprintf('Net Load Recurrence Heatmap: Luzon - REF %d (Up to 144 Hours)', target_year);
    title(title_str, 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    
    hold on;
    xline(current_dependable / 1000, 'r-', 'LineWidth', 2.5);
    text((current_dependable / 1000) * 1.05, y_max_short * 0.15, 'Dependable Capacity Limit', ...
         'Color', 'r', 'FontWeight', 'bold', 'FontSize', 24, 'Rotation', 90, ...
         'BackgroundColor', [1 1 1 0.8], 'Margin', 2, 'FontName', 'Times New Roman');

    hold off;
    
    out_path_short = fullfile(output_dir, sprintf('LuzonREF%d_144Hours.png', target_year));
    exportgraphics(fig1, out_path_short, 'Resolution', 600);
    close(fig1); 
    
    %% 7B. PLOT 2: Full View
    fprintf('Rendering Plot 2 for %d...\n', target_year);
    fig2 = figure('Units', 'inches', 'Position', [1, 1, 16, 9.5], 'Color', 'w', 'Visible', 'off');
     
    % Convert to GW
    h2 = imagesc('XData', amplitudes / 1000, 'YData', durations, 'CData', heatmap_data);
    set(gca, 'YDir', 'normal'); 
    set(h2, 'AlphaData', ~isnan(heatmap_data)); 
    
    y_max_full = max_duration;
    ylim([1, y_max_full]);
    xlim(x_lim_target / 1000);
     
    colormap(turbo);
    ax2 = gca; ax2.Color = 'w'; ax2.FontSize = 24; ax2.FontName = 'Times New Roman';
    ax2.LineWidth = 1.5; ax2.TickDir = 'out'; ax2.XColor = 'k'; ax2.YColor = 'k'; 
    box on;
     
    clim([0, max_val]); 
    cb2 = colorbar; 
    cb2.LineWidth = 1.2; 
    cb2.Color = 'k'; 
    cb2.Ticks = 0:20:max_val; 
    cb2.FontSize = 24;
    cb2.TickLabels = tick_labels; 
    ylabel(cb2, 'Number of Occurrences', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    
    xlabel('Net Load Amplitude (GW)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    ylabel('Event Duration (Consecutive Hours)', 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k'); 
    title_str2 = sprintf('Net Load Recurrence Heatmap: Luzon - REF %d (Full 40-Year View)', target_year);
    title(title_str2, 'FontSize', 24, 'FontWeight', 'bold', 'FontName', 'Times New Roman', 'Color', 'k');
    
    hold on;
    xline(current_dependable / 1000, 'r-', 'LineWidth', 2.5);
    text((current_dependable / 1000) * 1.05, y_max_full * 0.15, 'Dependable Capacity Limit', ...
         'Color', 'r', 'FontWeight', 'bold', 'FontSize', 24, 'Rotation', 90, ...
         'BackgroundColor', [1 1 1 0.8], 'Margin', 2, 'FontName', 'Times New Roman');

    hold off;
    
    out_path_full = fullfile(output_dir, sprintf('LuzonREF%d_FullView_Hours.png', target_year));
    exportgraphics(fig2, out_path_full, 'Resolution', 600);
    close(fig2); 
    
    fprintf('Finished scenario %d successfully.\n', target_year);
end