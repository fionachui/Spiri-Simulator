function [Control] = computedesiredacceleration(Control, Twist)
    % Computes the desired acceleration vector. 
    global g dZ 
    % Introduce vertical velocity control gain at recovery stage 3
    switch Control.recoveryStage
        case 0 
            Control.accelRef = [g/2; 0; 0];
            dZ = 0;
        case 1
            Control.accelRef = [-g; 0; 0];
        case 2
            Control.accelRef = [0; 0; g/2];
        case 3
            dZ = 5;
            Control.accelRef = [0; 0; 0];
        case 4
            dZ = 5;
        otherwise 
            error('Invalid recovery stage!');    
    end
    % Desired acceleration is the sum of a 1) gravity, 2) reference acceleration
    % and 3) vertical velocity control term
    Control.acc = [0; 0; g] + Control.accelRef + [0; 0; -dZ*Twist.posnDeriv(3)]; 
end