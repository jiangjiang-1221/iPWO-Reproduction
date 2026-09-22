function validate_tw()
% VALIDATE_TW  quickly check that time-window/capacity constraints are reachable and distinguish algorithms
%   longer budget + feasibility count, used to set the final difficulty level; no paper figures generated.
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir), script_dir = pwd; end
cd(script_dir); addpath(script_dir);
set(groot,'defaultTextInterpreter','none');

env = uav_delivery_env(6,6);
fobj = @(X) uav_delivery_cost(X, env);
algos = {'iPWO','PWO','GWO','MGO','SFOA'};
pop = 30; MaxFEs = 3000; runs = 5;

fprintf('Validation: Nu=%d Nc=%d Q=%.1f TW hw=%.0fs w=%.1f\n',...
    env.Nu, env.Nc, env.Q, (env.tw(1,2)-env.tw(1,1))/2, env.tw_w);

for a=1:numel(algos)
    Zv = zeros(runs,1); Mv = zeros(runs,1); Tv = zeros(runs,1); feas = 0;
    for r=1:runs
        seed = 9000000 + r*1000 + a*7;
        rng(seed);
        switch algos{a}
            case 'iPWO', [sc,sx] = iPWO(pop,MaxFEs,env.lb,env.ub,env.D,fobj);
            case 'PWO',  [sc,sx] = PWO_vec(pop,MaxFEs,env.lb,env.ub,env.D,fobj);
            case 'GWO',  [sc,sx] = GWO(pop,MaxFEs,env.lb,env.ub,env.D,fobj);
            case 'MGO',  [sc,sx] = MGO(pop,MaxFEs,env.lb,env.ub,env.D,fobj);
            case 'SFOA', [sc,sx] = SFOA(pop,MaxFEs,env.lb,env.ub,env.D,fobj);
        end
        [~,~,d] = uav_delivery_cost(sx, env);
        Zv(r) = d.makespan + d.pen_tw;
        Mv(r) = d.makespan; Tv(r) = d.pen_tw;
        if d.pen_tw < 5, feas = feas + 1; end
    end
    fprintf('%-5s Z[min=%.1f mean=%.1f] mk[min=%.1f] pen_tw[min=%.1f mean=%.1f] feas=%d/%d\n',...
        algos{a}, min(Zv), mean(Zv), min(Mv), min(Tv), mean(Tv), feas, runs);
end
end
