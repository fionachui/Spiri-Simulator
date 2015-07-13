function [signal_c,ez,evz,evx,evy,eyaw,eroll,epitch,er,omega,roll,pitch,yaw,roll_des,pitch_des,r_des,u1,u2,u3,u4] = ControllerZhang(x,i,t0,dt,ref_r,ref_head,ez_prev,evz_prev,eroll_prev,epitch_prev,er_prev,omega_prev)

global m g Kt Kr prop_loc Kp Kq Jr Dt Ixx Iyy Izz

% Add noise to state estimates
% x(1) = x(1) + (0.01).*randn(1);
% x(2) = x(2) + (0.01).*randn(1);
% x(3) = x(3) + (0.01).*randn(1);
% x(4) = x(4) + (1*pi/180).*randn(1);
% x(5) = x(5) + (1*pi/180).*randn(1);
% x(6) = x(6) + (1*pi/180).*randn(1);
% x(7) = x(7) + (0.01).*randn(1);
% x(8) = x(8) + (0.01).*randn(1);
% x(9) = x(9) + (0.01).*randn(1);

% x(10) = x(10) + (1*pi/180).*randn(1);
% x(11) = x(11) + (1*pi/180).*randn(1);
% x(12) = x(12) + (1*pi/180).*randn(1);
% x(13) = x(13) + (1*pi/180).*randn(1);

q = [x(10);x(11);x(12);x(13)]/norm(x(10:13));
R = quatRotMat(q);

[roll, pitch, yaw] = quat2angle(q,'xyz');


% roll2 = x(14);
% pitch2 = x(15);
% yaw2 = x(16);

%% Tait-Bryan Euler Angle rates
roll_w = x(4) + tan(pitch)*(x(5)*sin(roll)+x(6)*cos(roll));
pitch_w = x(5)*cos(roll) - x(6)*sin(roll);
yaw_w = sec(pitch)*(x(5)*sin(roll)+x(6)*cos(roll));

%% Zhang 2014
%% Altitude Controller Parameters
Kpz = 2;%20; %Zhang x4 value = 1
Kiz = 0;%40;
Kdz = 0;
Kpvz = 1.6;%10; %Zhang x4 value = 2.8
Kivz = 60;%10; %Zhang x4 value = 4

sat_v_des = 3; %Zhang x4 value = 0.6

%% Horizontal Position Controller Parameters
Kps = 1.2;%0.6; %Zhang x4 value = 0.6
Kpvx = 3.33; %Zhang x4 value = 2
Kpvy = 3.33; %Zhang x4 value = 2

Kpyaw = 0.7; %Zhang x4 value = 0.7

sat_vpos_des = 2.5; %Zhang x4 value = 1
sat_roll_des = 1;%0.2 %Zhang x4 value = 0.1
sat_pitch_des = 1;%0.2; %Zhang x4 value = 0.1
sat_r_des = 0.3; %Zhang x4 value = 0.3

%% Attitude Controller Parameters
Kprp = 10; %Zhang x4 value = 7.2
Kirp = 4; %Zhang x4 value = 4
Kdrp = 4.2; %Zhang x4 value = 4.2

Kpvyaw = 2.8; %Zhang x4 value = 2.8
Kivyaw = 4; %Zhang x4 value = 4;
Kdvyaw = 0; %Zhang x4 value = 0;

%% PID Altitude Controller
ez = ref_r(3) - x(9);
if i == t0
    i_z = 0;
    d_z = 0;    
else
    i_z = ez + ez_prev;
    d_z = ez - ez_prev;
end

v_des = Kpz*ez + Kiz*dt*(i_z)*0.5 + Kdz*(d_z)/dt;

% if v_des < 0
%     v_des = max([-sat_v_des,v_des]);
% else
%     v_des = min([v_des,sat_v_des]);
% end

evz = v_des - R(:,3)'*x(1:3)';
if i == t0
    evz_prev = -evz;
end

az = Kpvz*evz + Kivz*dt*(evz_prev+evz)*0.5;
az = R(3,3)*(az+g);

%% PI Horizontal Position Controller

% Roll & Pitch
ex = ref_r(1) - x(7);
ey = ref_r(2) - x(8);
es = sqrt(ex^2 + ey^2);    
if i == t0
    es_prev = -es;
end

vpos_des = Kps*es;
% if vpos_des < 0
%     vpos_des = max([-sat_vpos_des,vpos_des]);
% else
%     vpos_des = min([vpos_des,sat_vpos_des]);
% end

vx_des = vpos_des*cos(atan2(ey,ex));
vy_des = vpos_des*sin(atan2(ey,ex));

evx = vx_des - R(:,1)'*x(1:3)';
evy = vy_des - R(:,2)'*x(1:3)';

if i == t0
    evx_prev = -evx;
    evy_prev = -evy;
end

ax = Kpvx*evx;
ay = Kpvy*evy;
a = [ax;ay;0];

ax = R(1,:)*a;
ay = R(2,:)*a;
az2 = R(3,:)*a;
u1 = m*(az+az2);

% pitch_des = -(cos(yaw)*ax + sin(yaw)*ay)/g;
% roll_des = -(sin(yaw)*ax - cos(yaw)*ay)/g;

roll_des = ay/g;
pitch_des = -ax/g;

% if pitch_des < 0
%     pitch_des = max([-sat_pitch_des,pitch_des]);
% else
%     pitch_des = min([pitch_des,sat_pitch_des]);
% end
% 
% if roll_des < 0
%     roll_des = max([-sat_roll_des,roll_des]);
% else
%     roll_des = min([roll_des,sat_roll_des]);
% end


% Yaw
eyaw = ref_head - yaw;
r_des = Kpyaw*eyaw;
% if r_des < 0
%     r_des = max([-sat_r_des,r_des]);
% else
%     r_des = min([r_des,sat_r_des]);
% end

%% For Gareth testing Attitude Controller only:
% roll_des = 0.1;
% pitch_des = 0.1;
% r_des = 0.1;

%% Attitude Controller
%inputs: roll_des, pitch_des, r_des
%output: prop_speed, prop_accel

eroll = roll_des - roll;
epitch = pitch_des - pitch;
er = r_des - x(6);

if i == t0
    i_roll = 0;
    i_pitch = 0;
    i_r = 0;
    
    d_roll = 0;
    d_pitch = 0;
    d_r = 0;
else
    i_roll = eroll + eroll_prev;
    i_pitch = epitch + epitch_prev;
    i_r = er + er_prev;
    
    d_roll = eroll - eroll_prev;
    d_pitch = epitch - epitch_prev;
    d_r = er - er_prev;
end

v_roll = Kprp*eroll + Kirp*dt*(i_roll)*0.5 + Kdrp*(d_roll)/dt;
v_pitch = Kprp*epitch + Kirp*dt*(i_pitch)*0.5 + Kdrp*(d_pitch)/dt;
v_r =  Kpvyaw*er + Kivyaw*dt*(i_r)*0.5 + Kdvyaw*(d_r)/dt;

u2 = (v_roll - x(5)*x(6)*(Iyy-Izz)/Ixx)*Ixx;
u3 = (v_pitch - x(4)*x(6)*(Izz-Ixx)/Iyy)*Iyy;
u4 = (v_r - x(4)*x(5)*(Ixx-Iyy)/Izz)*Izz;

%Thrust and Moment Control Signal
signal_c = [u1;u2;u3;u4];

%Propeller Speed and Acceleration Control Signal
A = [-Kt -Kt -Kt -Kt;...
    -Kt*prop_loc(2,1) -Kt*prop_loc(2,2) -Kt*prop_loc(2,3) -Kt*prop_loc(2,4);...
    Kt*prop_loc(1,1) Kt*prop_loc(1,2) Kt*prop_loc(1,3) Kt*prop_loc(1,4);...
    -Dt Dt -Dt Dt];

temp = inv(A)*signal_c;
omegasquare = temp.*(temp>0);
omega = sqrt(omegasquare);
omega = [-omega(1);omega(2);-omega(3);omega(4)];
omegadot = (omega - omega_prev)/dt;
signal_c = [omega;omegadot];


end
