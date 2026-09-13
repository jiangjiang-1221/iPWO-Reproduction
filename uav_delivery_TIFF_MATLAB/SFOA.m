function [best_cost, best_pos, Convergence_curve] = SFOA(N, MaxFEs, lb, ub, dim, fobj)
% SFOA - Starfish Optimization Algorithm (2024-2025)
%   Bio-inspired metaheuristic mimicking starfish exploration,
%   preying (two-directional search), and regeneration.
%   Interface: [best_cost, best_pos, Convergence_curve] = SFOA(N,MaxFEs,lb,ub,dim,fobj)
%
%   Reference: Starfish Optimization Algorithm (SFOA), Nature Scientific Reports 2025
%   Phases: Initialization → Exploration (5-arm / 1-dim) → Exploitation (preying) → Regeneration

    if isscalar(lb), lb = repmat(lb,1,dim); else lb=lb(:)'; end
    if isscalar(ub), ub = repmat(ub,1,dim); else ub=ub(:)'; end

    maxIter = ceil(MaxFEs / N);
    Convergence_curve = zeros(1,maxIter);

    X = rand(N,dim).*repmat(ub-lb,N,1)+repmat(lb,N,1);
    Fit = inf(N,1); FEs = 0;
    for i=1:N, Fit(i)=fobj(X(i,:)); FEs=FEs+1; end
    [best_cost,bi]=min(Fit); best_pos=X(bi,:);
    iter=1;

    while FEs < MaxFEs && iter <= maxIter
        T=iter; Tmax=maxIter;
        [gbest_cost,gi]=min(Fit);
        Xb=X(gi,:);
        if gbest_cost<best_cost, best_cost=gbest_cost; best_pos=Xb; end

        % === Exploration ===
        for i=1:N
            Xi=X(i,:);
            if dim>5
                p=randperm(dim,5);
                for kk=1:5
                    pk=p(kk);
                    a1=(2*rand-1)*pi;
                    theta=(pi/2)*(T/Tmax);
                    if rand<=0.5
                        Yi=Xi(pk)+a1*(Xb(pk)-Xi(pk))*cos(theta);
                    else
                        Yi=Xi(pk)-a1*(Xb(pk)-Xi(pk))*sin(theta);
                    end
                    Xi(pk)=Yi;
                end
            else
                pk=randi(dim);
                a1=(2*rand-1)*pi;
                theta=(pi/2)*(T/Tmax);
                if rand<=0.5
                    Yi=Xi(pk)+a1*(Xb(pk)-Xi(pk))*cos(theta);
                else
                    Yi=Xi(pk)-a1*(Xb(pk)-Xi(pk))*sin(theta);
                end
                Xi(pk)=Yi;
            end
            Xi=max(min(Xi,ub),lb);
            if FEs>=MaxFEs, break; end
            fi=fobj(Xi); FEs=FEs+1;
            if fi<Fit(i), X(i,:)=Xi; Fit(i)=fi;
                if fi<best_cost, best_cost=fi; best_pos=Xi; end
            end
        end

        % === Exploitation: Preying (two-directional) ===
        for i=1:N
            Xi=X(i,:);
            Yi=Xi+(2*rand(1,dim)-1).*abs(Xb-Xi).*0.5;
            Yi=max(min(Yi,ub),lb);
            if FEs>=MaxFEs, break; end
            fi=fobj(Yi); FEs=FEs+1;
            if fi<Fit(i), X(i,:)=Yi; Fit(i)=fi;
                if fi<best_cost, best_cost=fi; best_pos=Yi; end
            end
        end

        % === Regeneration (adjust last individual toward best) ===
        if FEs < MaxFEs
            Xi=X(N,:);
            Yi=Xi+0.1*(Xb-Xi)*(1-T/Tmax);
            Yi=max(min(Yi,ub),lb);
            fi=fobj(Yi); FEs=FEs+1;
            if fi<Fit(N), X(N,:)=Yi; Fit(N)=fi;
                if fi<best_cost, best_cost=fi; best_pos=Yi; end
            end
        end

        Convergence_curve(iter)=best_cost;
        iter=iter+1;
    end
    Convergence_curve=Convergence_curve(1:iter-1);
end
