function plot_dttl_halfcycle(root, runDir)
% Plot the real RTL symbol trace produced by run_dttl_supervisor_sim.ps1.
if nargin == 0
    root = fileparts(fileparts(mfilename('fullpath')));
end
if nargin < 2
    runDir = fullfile(root,'temp','dttl_supervisor_sim');
end
t = readtable(fullfile(runDir,'halfcycle_symbols.csv'));
fig = figure('Visible','off','Color','w','Position',[100 100 1200 700]);
layout = tiledlayout(fig,2,2,'TileSpacing','compact');
names = {'Alternating 1010: half-cycle initial offset','PRBS: half-cycle initial offset'};
for scenario = 0:1
    nexttile(layout,scenario*2+1); hold on; grid on;
    for loop = 0:1
        rows = t.scenario==scenario & t.loop==loop;
        p = t.phase_error(rows)/2^32;
        plot(t.symbol(rows),min(p,1-p),'LineWidth',1.2);
    end
    yline(0.05,'k:'); ylim([0 0.55]);
    ylabel('Distance from TX boundary (symbols)'); xlabel('RX symbol');
    title(names{scenario+1}); legend('Without supervisor','With supervisor','0.05T','Location','best');
    nexttile(layout,scenario*2+2); hold on; grid on;
    rows=t.scenario==scenario & t.loop==1;
    plot(t.symbol(rows),abs(t.entire(rows))/191812.5,'LineWidth',1);
    plot(t.symbol(rows),abs(t.middle(rows))/191812.5,'LineWidth',1);
    xlabel('RX symbol'); ylabel('Magnitude / nominal full-symbol integral');
    title('Supervised DTTL integrals'); legend('|Entire|','|Middle|','Location','best');
end
title(layout,'DTTL MODE 3: real RTL + Divider Generator netlist');
if ~exist(fullfile(root,'reports'),'dir'), mkdir(fullfile(root,'reports')); end
exportgraphics(fig,fullfile(root,'reports','dttl_halfcycle.png'),'Resolution',160);
close(fig);
end
