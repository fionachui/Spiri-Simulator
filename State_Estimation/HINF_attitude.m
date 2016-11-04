function [HINF] = HINF_attitude(Sensor, HINF, EKF, sensParams, tStep)
% HINF - kinematic prediction for orientation
% unit norm constrained H infinity (min max) filter
% using the predict correct structure

%notation - _k_1 is previous timestep, _k_m is predicted, _k is corrected
%estimate

global g mag
%unpackage
%states
pos_k_1 = EKF.X_hat.pos_hat;

vel_k_1 = EKF.X_hat.vel_hat;

q_k_1 = HINF.X_hat.q_hat;

omega_k_1 = HINF.X_hat.omega_hat;

rotMat = quat2rotmat(q_k_1);

%bias terms
% bias_acc = EKF.X_hat.bias_acc;
bias_gyr = HINF.X_hat.bias_gyr;
bias_acc = sensParams.bias.acc; %no accel bias so comparison is better

%measurements
u_b_acc = Sensor.acc;
u_b_gyr = Sensor.gyro;
u_b_mag = Sensor.mag;

u_b_gps = Sensor.gps;

u_b_baro = Sensor.baro;



%% predict
%quaternion

% % Euler discretization:
% omega_hat_m = u_b_gyr - bias_gyr;
% 
% q_k_m = q_k_1 - tStep*0.5*quatmultiply([0;omega_hat_m],q_k_1);

% % power series discretization
omega_hat_m = u_b_gyr - bias_gyr; %ang vel estimate

psi_norm = norm(omega_hat_m,2);
psi_k_p = sin(-0.5*psi_norm*tStep)*omega_hat_m/psi_norm;

%ang vel matrix used in discretization
Omega_k_m = [cos(-0.5*psi_norm*tStep), -psi_k_p';
            psi_k_p, cos(-0.5*psi_norm*tStep)*eye(3)+cross_mat(psi_k_p)];

q_k_m = Omega_k_m*q_k_1;

%renormalize quaternion (just in case)
q_k_m = q_k_m/norm(q_k_m,2);

bias_gyr_k_m = bias_gyr;

%discretized (euler discretization) then linearized state transition matrix
A_k_1_1 = eye(4)+[0, -omega_hat_m'; omega_hat_m, cross_mat(omega_hat_m)];

A_k_1_2 = [q_k_m(2), q_k_m(3), q_k_m(4);
           -q_k_m(1), -q_k_m(4), q_k_m(3);
           q_k_m(4), -q_k_m(1), -q_k_m(2);
           -q_k_m(3), q_k_m(2), -q_k_m(1)];
       
A_k_1 = [ -0.5*tStep*[A_k_1_1, A_k_1_2];
          zeros(3,4), eye(3)];

% process noise weighting matrix, could change if we know gyro noise is more?
B_k_1 = tStep*blkdiag(eye(4), eye(3)); 

%predict covariance matrix
HINF.P_hat = A_k_1*HINF.P_hat_eps*A_k_1' + B_k_1*B_k_1';

%% update 

dR_dq_0 = [q_k_m(1), -q_k_m(4), q_k_m(3);
             q_k_m(4), q_k_m(1), -q_k_m(2);
             -q_k_m(3), q_k_m(2), q_k_m(1)];

dR_dq_1 = [q_k_m(2), q_k_m(3), q_k_m(4);
             q_k_m(3), -q_k_m(2), -q_k_m(1);
             q_k_m(4), q_k_m(1), -q_k_m(2)];
         
dR_dq_2 = [-q_k_m(3), q_k_m(2), q_k_m(1);
             q_k_m(2), q_k_m(3), q_k_m(4);
             -q_k_m(1), q_k_m(4), -q_k_m(3)];
         
         
dR_dq_3 = [-q_k_m(4), -q_k_m(1), q_k_m(2);
             q_k_m(1), -q_k_m(4), q_k_m(3);
             q_k_m(2), q_k_m(3), q_k_m(4)];
         
rotMat = quat2rotmat( q_k_m );

if norm(u_b_acc,2) > norm(g,2) + HINF.accel_bound || norm(u_b_acc,2) < norm(g,2) - HINF.accel_bound
    
    %magnetometer only
    C_k = [dR_dq_0*mag, dR_dq_1*mag, dR_dq_2*mag, dR_dq_3*mag, zeros(3)];
    
    y_k = u_b_mag;
    
    y_k_hat = C_k*[q_k_m; bias_gyr_k_m];
    
    y_k_hat = rotMat*mag;
    
    meas_size = 3;

else
    
    %magnetometer and accelerometer
    C_k = [dR_dq_0*[0;0;g], dR_dq_1*[0;0;g], dR_dq_2*[0;0;g], dR_dq_3*[0;0;g], zeros(3);
           dR_dq_0*mag, dR_dq_1*mag, dR_dq_2*mag, dR_dq_3*mag, zeros(3)];
    
    y_k = [u_b_acc; u_b_mag];
    
    y_k_hat = C_k*[q_k_m; bias_gyr_k_m];
    
    y_k_hat = [rotMat*[0;0;g]; rotMat*mag];
    
    meas_size = 6;
       
end

%Here the process is broken down based on matrix inversions - in order to
%more easily facilitate coding in c++ later on.

% find kalman gain for the quaternion:
D_3 = HINF.P_hat*HINF.G_k'/(eye(4)-HINF.G_k*HINF.P_hat*HINF.G_k')*HINF.G_k;

D_1 = (D_3(1:4,1:4) + eye(4))*HINF.P_hat(1:4,1:7)*C_k';

D_2 = C_k*D_3*HINF.P_hat*C_k' + C_k*HINF.P_hat*C_k' + eye(meas_size);

K_k1_p1 = D_1/D_2;

r_k = y_k - y_k_hat;

r_k_D_2 = r_k'/D_2;

r_k_tilde = r_k_D_2*r_k;

x_k_tilde = K_k1_p1*r_k + q_k_m;

K_k1 = K_k1_p1 + (1/norm(x_k_tilde,2) - 1)*x_k_tilde*r_k_D_2/r_k_tilde;


%find kalman gain for the bias term - since G_k = 0 for bias just use basic
%kalman equations

K_k2 = HINF.P_hat(5:7,:)*C_k'/(eye(meas_size) + C_k*HINF.P_hat*C_k')';

K_k = [K_k1; K_k2];

L_k = (eye(7) - K_k*C_k)*HINF.P_hat*HINF.G_k'/(eye(4) - HINF.G_k*HINF.P_hat*HINF.G_k');

%update covariance
HINF.P_hat_eps = (eye(7) - K_k*C_k + L_k*HINF.G_k)*HINF.P_hat*(eye(7) - K_k*C_k + L_k*HINF.G_k)' + K_k*K_k' - L_k*L_k';

%update states
HINF.X_hat.q_hat = q_k_m + K_k1*r_k;

HINF.X_hat.q_hat = HINF.X_hat.q_hat/norm(HINF.X_hat.q_hat,2); % renormalize

HINF.X_hat.bias_gyr = bias_gyr_k_m + K_k2*r_k;

HINF.X_hat.omega_hat = u_b_gyr - HINF.X_hat.bias_gyr;

HINF.P_hat_eps = 0.5*(HINF.P_hat_eps + HINF.P_hat_eps'); % make sure symetric




