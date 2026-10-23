function fig = plot_bms_results(R, fig_title)
%PLOT_BMS_RESULTS  Six-panel result figure: SOC, V, I, T, fault flags, combined.
%   R is the struct returned by simulate_bms (or built by EV_BMS_StageA).

    if nargin < 2, fig_title = R.name; end
    P = R.P;  t = R.t / 60;                 % plot time in minutes
    fig = figure('Name', fig_title, 'NumberTitle', 'off', 'Position', [60 60 1100 800]);

    subplot(3,2,1);
    plot(t, R.SOC_true, 'b', t, R.SOC_est, 'r--', 'LineWidth', 1.4);
    ylabel('SOC (%)'); ylim([-5 105]); grid on; legend('True', 'Coulomb counting', 'Location', 'best');
    title('State of charge');

    subplot(3,2,2);
    plot(t, R.V, 'b', 'LineWidth', 1.4); hold on;
    plot([t(1) t(end)], [P.V_max P.V_max], 'r--', [t(1) t(end)], [P.V_min P.V_min], 'm--');
    ylabel('Voltage (V)'); grid on; legend('V', 'V_{max}', 'V_{min}', 'Location', 'best');
    title('Terminal voltage');

    subplot(3,2,3);
    plot(t, R.I_meas, 'b', 'LineWidth', 1.4); hold on;
    plot([t(1) t(end)], [P.I_max P.I_max], 'r--', [t(1) t(end)], [-P.I_max -P.I_max], 'r--');
    ylabel('Current (A)'); grid on; title('Current (+ discharge, - charge)');

    subplot(3,2,4);
    plot(t, R.T, 'b', 'LineWidth', 1.4); hold on;
    plot([t(1) t(end)], [P.T_max P.T_max], 'r--');
    ylabel('Temperature (^{\circ}C)'); grid on; title('Pack temperature');

    subplot(3,2,5);
    stairs(t, double(R.OV) + 3.0, 'r', 'LineWidth', 1.2); hold on;
    stairs(t, double(R.UV) + 2.0, 'm', 'LineWidth', 1.2);
    stairs(t, double(R.OC) + 1.0, 'k', 'LineWidth', 1.2);
    stairs(t, double(R.OT) + 0.0, 'Color', [0.9 0.5 0], 'LineWidth', 1.2);
    set(gca, 'YTick', [0.5 1.5 2.5 3.5], 'YTickLabel', {'OT', 'OC', 'UV', 'OV'});
    ylim([-0.2 4.4]); xlabel('Time (min)'); grid on; title('Individual fault flags');

    subplot(3,2,6);
    stairs(t, double(R.any_fault), 'r', 'LineWidth', 1.4); hold on;
    stairs(t, double(R.contactor_closed) * 0.9, 'g--', 'LineWidth', 1.2);
    ylim([-0.1 1.2]); xlabel('Time (min)'); grid on;
    legend('Combined fault', 'Contactor closed', 'Location', 'best');
    title('Combined fault and simulated contactor');
end
