function export_scene_json()
% EXPORT_SCENE_JSON  export the real MATLAB scenario + iPWO best solution to JSON,
%   for reuse by the Python preview plot, keeping coordinates, obstacles, assignment and paths identical point-by-point.
%
% data source: env (scenario) and best_diag (best solution) in data/delivery_results.mat.
% output:  data/scene_and_solution.json
%
% usage (MATLAB command line):
%   cd('D:/File/GPTTest/uav_delivery'); export_scene_json;

    matfile = fullfile(fileparts(mfilename('fullpath')), 'data', 'delivery_results.mat');
    if ~exist(matfile, 'file')
        error('delivery_results.mat not found. Run run_uav_delivery first to generate results.');
    end
    D = load(matfile, 'env', 'best_diag');
    env = D.env;
    bd  = D.best_diag;

    % ---- robust extraction (handles both struct and 1x1 cell wrapping)----
    R = bd.R;           if iscell(R), R = R{1}; end
    tms = bd.times;     if iscell(tms), tms = tms{1}; end
    ld0 = bd.load0;     if iscell(ld0), ld0 = ld0{1}; end

    out = struct();
    out.depot       = double(env.depot);
    out.pads        = double(env.pads);          % Nu×3 ground launch pads per UAV
    out.cruise_pts  = double(env.cruise_pts);    % Nu×3 cruise-and-hover points per UAV
    out.customers   = double(env.customers);   % Nc x 3
    out.weights     = double(env.weights(:));  % Nc x 1
    out.cyl         = double(env.cyl);          % m x 4  [x y radius height]
    out.sph         = double(env.sph);          % k x 4  [x y z radius]
    out.params = struct(...
        'Nu', env.Nu, 'Nc', env.Nc, 'Q', env.Q, 'V', env.V, 'TS', env.TS, ...
        'dmin', env.dmin, 'CRUISE', env.CRUISE, 'MAX_CLIMB', env.MAX_CLIMB, ...
        'MIN_SEG', env.MIN_SEG, 'F', env.F, 'K', env.K);

    out.assign   = double(R.assign(:).');       % 1 x Nc, UAV assigned to each customer (1-based)
    out.cust_seq = R.cust_seq;                  % cell of Nu vectors, customer visit order per UAV (1-based)
    out.routes   = {};                          % cell of Nu matrices (N x 3) trajectory node sequence
    for u = 1:env.Nu
        out.routes{u} = double(R.routes{u});
    end
    out.times   = double(tms(:).');             % 1 x Nu, completion time per UAV
    out.load0   = double(ld0(:).');             % 1 x Nu, initial load per UAV
    out.makespan= double(bd.makespan);
    out.L_total = double(bd.L_total);
    out.pen = struct('cap', double(bd.pen_cap), 'obs', double(bd.pen_obs), ...
                     'conf', double(bd.pen_conf), 'kin', double(bd.pen_kin));

    % ---- encode as JSON (UTF-8)----
    json = jsonencode(out);
    outfile = fullfile(fileparts(mfilename('fullpath')), 'data', 'scene_and_solution.json');
    fid = fopen(outfile, 'w', 'n', 'UTF-8');
    fwrite(fid, json, 'char');
    fclose(fid);

    fprintf('exported scenario + best solution: %s\n', outfile);
    fprintf('  customers=%d  UAVs=%d  makespan=%.2f s\n', env.Nc, env.Nu, bd.makespan);
    fprintf('  penalty: cap=%.3g obs=%.3g conf=%.3g kin=%.3g\n', ...
        bd.pen_cap, bd.pen_obs, bd.pen_conf, bd.pen_kin);
    fprintf('  per-UAV: load0=%s  times=%s\n', ...
        mat2str(out.load0), mat2str(out.times));
end
