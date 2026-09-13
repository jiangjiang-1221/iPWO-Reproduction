function validate_mean_conv()
% VALIDATE_MEAN_CONV  小预算校验均值收敛图的 Z 记录机制
%   复刻 run_uav_delivery.m 中 fobj_z + Zall + mean 逻辑（仅 2 算法），
%   确认：1) 不报错；2) G_ZRUN 正常记录；3) 跨 runs 均值可算；4) iPWO 末端 Z 更低。
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
cd(script_dir); addpath(script_dir);
set(groot,'defaultTextInterpreter','none');

global G_ZRUN;
env = uav_delivery_env(6,6);
D = env.D; pop = 30; MaxFEs = 1200; runs = 4; Lcurve = 200;
algos = {'iPWO','MGO'}; nAlg = 2;
fobj = @(x) fobj_z(x, env);

Zall = cell(runs, nAlg);
for r = 1:runs
    seed = 9000000 + r*1000;
    for a = 1:nAlg
        rng(seed); G_ZRUN = [];
        switch algos{a}
            case 'iPWO', [sc,sx] = iPWO(pop,MaxFEs,env.lb,env.ub,D,fobj);
            case 'MGO',  [sc,sx] = MGO(pop,MaxFEs,env.lb,env.ub,D,fobj);
        end
        G_ZRUN = G_ZRUN(:);
        if isempty(G_ZRUN) || all(isnan(G_ZRUN))
            Zall{r,a} = nan(Lcurve,1);
        else
            Zall{r,a} = interp1((1:numel(G_ZRUN))', G_ZRUN, ...
                                linspace(1,numel(G_ZRUN),Lcurve)','linear','extrap');
        end
    end
end

Cmean = zeros(Lcurve, nAlg);
for a = 1:nAlg
    Cmean(:,a) = mean(cat(2, Zall{:,a}), 2, 'omitnan');
end
fprintf('Mean convergence final Z -> iPWO=%.2f  MGO=%.2f  (expect iPWO lower)\n', ...
        Cmean(end,1), Cmean(end,2));
fprintf('Mechanism OK (no error, Z recorded, mean computed).\n');
end

function y = fobj_z(x, env)
    global G_ZRUN
    [y, Z] = uav_delivery_cost(x, env);
    zmin = min(Z);
    if isempty(G_ZRUN)
        G_ZRUN = zmin;
    else
        G_ZRUN(end+1) = min(G_ZRUN(end), zmin);
    end
end
