matpath = 'D:/File/GPTTest/uav_delivery/uav_delivery_TIFF_MATLAB/data/delivery_results.mat';
load(matpath);
fprintf('=== routes / cust_seq 结构 ===\n');
for u=1:env.Nu
    nr = size(best_diag.R.routes{u},1);
    ns = numel(best_diag.R.cust_seq{u});
    fprintf('UAV-%d: routes rows=%d, cust_seq len=%d\n', u, nr, ns);
end
fprintf('=== tw / arr ===\n');
fprintf('env.tw size=%s\n', mat2str(size(env.tw)));
if isfield(env,'tw'), fprintf('tw sample rows1-5: %s\n', mat2str(env.tw(1:5,:))); end
if isfield(best_diag,'arr')
    for u=1:env.Nu
        a = best_diag.arr{u};
        fprintf('arr{%d} size=%s min=%g max=%g anyNaN=%d\n', u, mat2str(size(a)), min(a(:)), max(a(:)), any(isnan(a(:))));
    end
else
    fprintf('best_diag 没有 arr 字段\n');
end
fprintf('=== 重算 route_timing 检查 ===\n');
for u=1:env.Nu
    nodes = best_diag.R.routes{u};
    seq = best_diag.R.cust_seq{u};
    [arr_u, late_u, comp_u] = route_timing(nodes, seq, env);
    fprintf('UAV-%d: route_timing arr size=%s anyNaN=%d late=%g comp=%g\n', ...
        u, mat2str(size(arr_u)), any(isnan(arr_u)), late_u, comp_u);
end

function [arr, late, completion] = route_timing(nodes, seq, env)
nC = numel(seq);
if ~isfield(env, 'tw') || nC == 0
    seg = diff(nodes, 1, 1); sl = sqrt(sum(seg.^2, 2));
    completion = sum(sl)/env.V + nC*env.TS;
    arr = zeros(nC, 1); late = 0; return;
end
arr = zeros(nC, 1);
late = 0; t = 0;
prev = nodes(1, :);
hi = 0;
for idx = 2:size(nodes, 1)
    seg = nodes(idx, :) - prev; sl = sqrt(sum(seg.^2));
    t = t + sl/env.V;
    if idx >= 3 && idx <= 2 + nC          % 客户上方巡航悬停投递点
        hi = hi + 1;
        j = seq(hi);
        e = env.tw(j, 1); l = env.tw(j, 2);
        if t < e, t = e; end
        if t > l, late = late + (t - l); end
        arr(hi) = t;
        t = t + env.TS;
    end
    prev = nodes(idx, :);
end
completion = t;
end
