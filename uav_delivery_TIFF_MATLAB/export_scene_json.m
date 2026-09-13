function export_scene_json()
% EXPORT_SCENE_JSON  把 MATLAB 的真实场景 + iPWO 最优解导出为 JSON，
%   供 Python 预览图复用，确保两边坐标、障碍、分配、航线逐点一致。
%
% 数据源：data/delivery_results.mat 中的 env（场景）与 best_diag（最优解）。
% 输出：  data/scene_and_solution.json
%
% 用法（MATLAB 命令行）：
%   cd('D:/File/GPTTest/uav_delivery'); export_scene_json;

    matfile = fullfile(fileparts(mfilename('fullpath')), 'data', 'delivery_results.mat');
    if ~exist(matfile, 'file')
        error('delivery_results.mat not found. 请先运行 run_uav_delivery 生成结果。');
    end
    D = load(matfile, 'env', 'best_diag');
    env = D.env;
    bd  = D.best_diag;

    % ---- 鲁棒提取（兼容 struct 与 1x1 cell 两种包装）----
    R = bd.R;           if iscell(R), R = R{1}; end
    tms = bd.times;     if iscell(tms), tms = tms{1}; end
    ld0 = bd.load0;     if iscell(ld0), ld0 = ld0{1}; end

    out = struct();
    out.depot       = double(env.depot);
    out.pads        = double(env.pads);          % Nu×3 各机地面起降坪
    out.cruise_pts  = double(env.cruise_pts);    % Nu×3 各机巡航悬停点
    out.customers   = double(env.customers);   % Nc x 3
    out.weights     = double(env.weights(:));  % Nc x 1
    out.cyl         = double(env.cyl);          % m x 4  [x y radius height]
    out.sph         = double(env.sph);          % k x 4  [x y z radius]
    out.params = struct(...
        'Nu', env.Nu, 'Nc', env.Nc, 'Q', env.Q, 'V', env.V, 'TS', env.TS, ...
        'dmin', env.dmin, 'CRUISE', env.CRUISE, 'MAX_CLIMB', env.MAX_CLIMB, ...
        'MIN_SEG', env.MIN_SEG, 'F', env.F, 'K', env.K);

    out.assign   = double(R.assign(:).');       % 1 x Nc，每客户归属无人机(1-based)
    out.cust_seq = R.cust_seq;                  % cell of Nu 向量，每机客户访问顺序(1-based)
    out.routes   = {};                          % cell of Nu 矩阵 (N x 3) 航迹节点序列
    for u = 1:env.Nu
        out.routes{u} = double(R.routes{u});
    end
    out.times   = double(tms(:).');             % 1 x Nu，各机完成时间
    out.load0   = double(ld0(:).');             % 1 x Nu，各机初始载重
    out.makespan= double(bd.makespan);
    out.L_total = double(bd.L_total);
    out.pen = struct('cap', double(bd.pen_cap), 'obs', double(bd.pen_obs), ...
                     'conf', double(bd.pen_conf), 'kin', double(bd.pen_kin));

    % ---- 编码为 JSON（UTF-8）----
    json = jsonencode(out);
    outfile = fullfile(fileparts(mfilename('fullpath')), 'data', 'scene_and_solution.json');
    fid = fopen(outfile, 'w', 'n', 'UTF-8');
    fwrite(fid, json, 'char');
    fclose(fid);

    fprintf('已导出场景+最优解: %s\n', outfile);
    fprintf('  客户数=%d  无人机数=%d  makespan=%.2f s\n', env.Nc, env.Nu, bd.makespan);
    fprintf('  惩罚: cap=%.3g obs=%.3g conf=%.3g kin=%.3g\n', ...
        bd.pen_cap, bd.pen_obs, bd.pen_conf, bd.pen_kin);
    fprintf('  各机: load0=%s  times=%s\n', ...
        mat2str(out.load0), mat2str(out.times));
end
