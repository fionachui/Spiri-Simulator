function dx = SpiriMotion(t,x,signal_c,wall_loc,wall_plane)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

global g m I Jr prop_loc Kt A d_air Cd V Tv Kp Kq Kr Dt Rbumper Cbumper;

q = [x(10);x(11);x(12);x(13)]/norm(x(10:13));
R = quatRotMat(q);

x = reshape(x,[max(size(x)),1]);

dx = zeros(13,1);

%% Controller Signal
prop_speed = signal_c(1:4);
prop_accel = signal_c(5:8);

%% Contact Detection
defl = 0;

if abs(wall_loc - x(7)) <= Rbumper
    if (sum(wall_plane == 'YZ')==2 || sum(wall_plane == 'ZY')==2)
        
        % Transform virtual bumper definitions to world frame
        bumper_n = R'*[0;0;1]; %normal to bumper circle
        bumper_u = R'*[1;0;0]; %in plane with bumper circle
        bumper_loc = R'*Cbumper + x(7:9);
        
        % Solve for intersection angle
        bumper_cross = cross(bumper_n,bumper_u);
        
        theta1 = -log((wall_loc - bumper_loc(1) + (bumper_loc(1)^2 - 2*bumper_loc(1)*wall_loc - Rbumper^2*bumper_u(1)^2 - Rbumper^2*bumper_cross(1)^2 + wall_loc^2)^(1/2))/(Rbumper*(bumper_u(1) - bumper_cross(1)*i)))*i;
        theta2 = -log(-(bumper_loc(1) - wall_loc + (bumper_loc(1)^2 - 2*bumper_loc(1)*wall_loc - Rbumper^2*bumper_u(1)^2 - Rbumper^2*bumper_cross(1)^2 + wall_loc^2)^(1/2))/(Rbumper*(bumper_u(1) - bumper_cross(1)*i)))*i;
        
        % Save intersection angle to base workspace
        assignin('base','theta1',theta1);
%         disp(theta1)
%         disp(theta1)
%         if abs(imag(theta1)) <= 1e-5
            theta1 = real(theta1);
            theta2 = real(theta2);
        
            % Calculate point of contact, deflection
            if theta1 == theta2 %1 pt of intersection
    %             disp('1 pt of intersection');
                defl = 0;
            else %2 pts of intersection
    %             disp('2 pt of intersection');

                % Find points of intersection
                pint1 = Rbumper*cos(theta1)*bumper_u + Rbumper*sin(theta1)*bumper_cross + bumper_loc;
                pint2 = Rbumper*cos(theta2)*bumper_u + Rbumper*sin(theta2)*bumper_cross + bumper_loc;

                % Find point of contact
                axisc_w = (pint1+pint2)/2 - bumper_loc; %axis pc lies on
                axisc_b = R*axisc_w;
                axisc_b = axisc_b/norm(axisc_b);

                if pint1(1) >= bumper_loc(1)
                    pc_b = [0;0;prop_loc(3,1)] + Rbumper*axisc_b;
                else
                    pc_b = [0;0;prop_loc(3,1)] - Rbumper*axisc_b;
                end

                pc_w = R'*pc_b + x(7:9);

                % Find deflection
                defl = pc_w(1) - wall_loc;

                if defl <= 0
                    defl = 0;
    %                     disp(defl)
%                         error('Deflection calc error');
                end

                % Save variables to base workspace
                assignin('base','pint1',pint1);
                assignin('base','pc_w',pc_w);
                assignin('base','pint2',pint2);

            end %else no contact
            
%         end

    end
end
assignin('base','defl',defl);

%% Calculate contact force and moment
if defl > 0
    Fc_mag = 500*defl^2;

    Fc_w = [-Fc_mag;0;0];
    Fc_b = R*Fc_w;
        
    Mc = cross(pc_b,Fc_b);
else
    Fc_b = [0;0;0];
    Mc = [0;0;0];
end

Fg = R*[0;0;-m*g];
Fa = Tv*[-0.5*d_air*V^2*A*Cd;0;0];
Ft = [0;0;-Kt*sum(prop_speed.^2)];
% Ft = [0;0;-signal_c(1)];

assignin('base','Ft',-Kt*sum(prop_speed.^2));
assignin('base','prop_speed',prop_speed);

% Mx = signal_c(2)-Kp*x(4)^2;%-x(5)*Jr*sum(prop_speed);
% My = signal_c(3)-Kq*x(5)^2;%+x(4)*Jr*sum(prop_speed);
% Mz = signal_c(4)-Kr*x(6)^2; %;-Jr*sum(prop_accel);

Mx = -Kt*prop_loc(2,:)*(prop_speed.^2)-Kp*x(4)^2-x(5)*Jr*sum(prop_speed) + Mc(1);
My = Kt*prop_loc(1,:)*(prop_speed.^2)-Kq*x(5)^2+x(4)*Jr*sum(prop_speed) + Mc(2);
Mz =  [-Dt Dt -Dt Dt]*(prop_speed.^2)-Kr*x(6)^2-Jr*sum(prop_accel) + Mc(3);

dx(1:3) = (Fg + Fa + Ft + Fc_b - m*cross(x(4:6),x(1:3)))/m;
dx(4:6) = inv(I)*([Mx;My;Mz]-cross(x(4:6),I*x(4:6)));
dx(7:9) = R'*x(1:3);
dx(10:13) = -0.5*quatmultiply([0;x(4:6)],q);

% dx(14) = [1 sin(x(14))*tan(x(15)) cos(x(14))*tan(x(15))]*x(4:6);
% dx(15) = [0 cos(x(14)) -sin(x(14))]*x(4:6);
% dx(16) = [0 sin(x(14))/cos(x(15)) cos(x(14))/cos(x(15))]*x(4:6); 


end
