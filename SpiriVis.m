function [ ] =SpiriVis( record,t,X,sideview,wall_loc,wall_plane, pint11_hist,pint12_hist,pc_w1_hist,pint21_hist,pint22_hist,pc_w2_hist ,pc_w3_hist ,pc_w4_hist )
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here
global prop_loc Rbumper Cbumper Abumper

disprate = 200; %Hz
recordrate = disprate/4; %Hz
disprate_idx = round((size(t,1)/(t(end)-t(1)))/disprate);
% disprate_idx = 2;

figure('units','normalized','outerposition',[0 0 1 1])

%% Create body-fixed centers of 4 bumpers + virtual bumper
load('locations2');
% c1 = [0.2*cos(pi/4);0.2*cos(pi/4);prop_loc(3,1)];
% c2 = [-0.2*cos(pi/4);0.2*cos(pi/4);prop_loc(3,2)];
% c3 = [-0.2*cos(pi/4);-0.2*cos(pi/4);prop_loc(3,3)];
% c4 = [0.2*cos(pi/4);-0.2*cos(pi/4);prop_loc(3,4)];
c1 = prop_loc(:,1);
c2 = prop_loc(:,2);
c3 = prop_loc(:,3);
c4 = prop_loc(:,4);

n1_b = RotMat('Z',deg2rad(45))'*RotMat('Y',Abumper + deg2rad(90))'* [1;0;0];
n2_b = RotMat('Z',deg2rad(135))'*RotMat('Y',Abumper + deg2rad(90))'* [1;0;0];
n3_b = RotMat('Z',deg2rad(-135))'*RotMat('Y',Abumper + deg2rad(90))'* [1;0;0];
n4_b = RotMat('Z',deg2rad(-45))'*RotMat('Y',Abumper + deg2rad(90))'* [1;0;0];
   
cR = Cbumper;

clear p1 p2 p3 p4;


%% Create body-fixed points of spherical bumper
[sx,sy,sz] = sphere;
sx = sx(9:13,:);
sy = sy(9:13,:);
sz = sz(9:13,:)+prop_loc(3,1);
sr = Rbumper;
sxR = zeros(size(sx));
syR = zeros(size(sy));
szR = zeros(size(sz));

%% Create body-fixed points of Spiri body
p1 = [0.08;0.0115;0]-CoM;
p2 = [0;0.0575;0]-CoM;
p3 = [-0.1;0;0]-CoM;
p4 = [0;-0.0575;0]-CoM;
p5 = [0.08;-0.0115;0]-CoM;


%% Create body-fixed axes
po = [0;0;0];
px = [0.1;0;0];
py = [0;0.1;0];
pz = [0;0;0.1];

%%  Calculate axes ranges for plotting
axis_min = min([min(X(:,7))-0.4,min(X(:,8))-0.4,min(X(:,9))-0.4]);
axis_max = max([max(X(:,7))+0.4,max(X(:,8))+0.4,max(X(:,9))+0.4]);

%% Create world-frame wall points
[wall_pts, wall_ln] = WallPts(wall_loc,wall_plane,-1,0,5,5);

if record == 1
    writerObj = VideoWriter('simulation.avi');
    writerObj.FrameRate = recordrate;
    open(writerObj);
end

for i = 1:size(t,1)
% for i = 241
   %% Rotate body-fixed points to world-frame points
   q = [X(i,10);X(i,11);X(i,12);X(i,13)];
   q = q/norm(q);
   R = quatRotMat(q);
   T = [X(i,7);X(i,8);X(i,9)];
   
   p1_p = R'*p1 + T;
   p2_p = R'*p2 + T;
   p3_p = R'*p3 + T;
   p4_p = R'*p4 + T;
   p5_p = R'*p5 + T;
   
   c1_p = R'*c1 + T;
   c2_p = R'*c2 + T;
   c3_p = R'*c3 + T;
   c4_p = R'*c4 + T;
   cR_p = R'*cR + T;
   
   po_p = R'*po + T;
   px_p = R'*px + T;
   py_p = R'*py + T;
   pz_p = R'*pz + T;
   
   pts = [p1_p p2_p p3_p p4_p p5_p p1_p];
   
   %% Plot Spiri body points
   plot3(pts(1,:),pts(2,:),pts(3,:),'Color',[154 215 227]/255,'LineWidth',2);
   hold on;
   plot3(T(1),T(2),T(3),'rx','MarkerSize',8); %Centre of mass
   
   %% Plot Spiri 2-d bumpers 
   normal = cross(p1_p-p2_p,p2_p-p3_p);

   n1_w = R'*n1_b;
   n2_w = R'*n2_b;
   n3_w = R'*n3_b;
   n4_w = R'*n4_b;
   
   plotCircle3D(c1_p,n1_w,Rbumper);
   plotCircle3D(c2_p,n2_w,Rbumper);
   plotCircle3D(c3_p,n3_w,Rbumper);
   plotCircle3D(c4_p,n4_w,Rbumper);
   
%    normal2 = cross(c1_p-c3_p,c2_p-c4_p);
%    plotCircle3D(cR_p,normal2,Rbumper); %Virtual bumper
   
   %% Plot Spiri spherical bumper
   for j = 1:size(sx,1)
       for k = 1:size(sx,2)
           sxR(j,k) = R(:,1)'*[sx(j,k);sy(j,k);sz(j,k)];
           syR(j,k) = R(:,2)'*[sx(j,k);sy(j,k);sz(j,k)];
           szR(j,k) = R(:,3)'*[sx(j,k);sy(j,k);sz(j,k)];       
       end
   end     
%    surf(sxR*sr+T(1),syR*sr+T(2),szR*sr+T(3),'FaceColor','y','FaceAlpha',0.2,'EdgeAlpha',0.5);

    %% Plot body-fixed axes
    xpts = [po_p px_p];
    ypts = [po_p py_p];
    zpts = [po_p pz_p];   

    plot3(xpts(1,:),xpts(2,:),xpts(3,:),'r-','LineWidth',1);
    plot3(ypts(1,:),ypts(2,:),ypts(3,:),'g-','LineWidth',1);
    plot3(zpts(1,:),zpts(2,:),zpts(3,:),'b-','LineWidth',1);

    %% Plot contact points
%    plot3(pint11_hist(1,i),pint11_hist(2,i),pint11_hist(3,i),'b*','MarkerSize',8);
%    plot3(pint12_hist(1,i),pint12_hist(2,i),pint12_hist(3,i),'b*','MarkerSize',8);
   plot3(pc_w1_hist(1,i),pc_w1_hist(2,i),pc_w1_hist(3,i),'mX','MarkerSize',10);
   
%    plot3(pint21_hist(1,i),pint21_hist(2,i),pint21_hist(3,i),'m*','MarkerSize',8);
%    plot3(pint22_hist(1,i),pint22_hist(2,i),pint22_hist(3,i),'m*','MarkerSize',8);
   plot3(pc_w2_hist(1,i),pc_w2_hist(2,i),pc_w2_hist(3,i),'mX','MarkerSize',10);
   
   plot3(pc_w3_hist(1,i),pc_w3_hist(2,i),pc_w3_hist(3,i),'mX','MarkerSize',10);

   plot3(pc_w4_hist(1,i),pc_w4_hist(2,i),pc_w4_hist(3,i),'mX','MarkerSize',10);


   %% Plot wall
   fill3(wall_pts(1,:)',wall_pts(2,:)',wall_pts(3,:)','r','FaceAlpha',0.4);
   plot3(wall_ln(1,1:2)',wall_ln(2,1:2)',wall_ln(3,1:2)','r-');
   plot3(wall_ln(1,3:4)',wall_ln(2,3:4)',wall_ln(3,3:4)','r-');

   %% Figure settings
   axis([axis_min,axis_max,axis_min,axis_max,axis_min,axis_max]);
%    axis([3,5,-1,1,3.5,5.5]);
%  axis([-20,20,-20,20,0,80]);
   xlabel('x^W');
   ylabel('y^W');
   zlabel('z^W');
   title(strcat('t = ',num2str(t(i),'%.2f'),' s'));
   
   if sideview == 'XZ'
        view([0 0]); %view XZ plane
        
   elseif sideview == 'ZX'
       view(-180,0);
   elseif sideview == 'YZ'
        view(90, 0); %view YZ plane
        
   elseif sideview == 'XY'
       view([0 0 1]);
       
   elseif sideview == 'V1'
       view([-14.5,6]);
       
   elseif sideview == 'V2'
       view([-19.5,28]);
       
   elseif sideview == 'V3'
       view(-130,14);
   end
   
   grid on;
   axis square;
   
%    xlim([0 1])
% ylim([-0.2 0.8])
% zlim([1.3 2.3])
% xlim([-2 2]);
% ylim([-2 2]);
% zlim([0 4]);
   drawnow;
   
   if record == 1
    frame = getframe;
    writeVideo(writerObj,frame);
   end
   
   hold off;
end

if record == 1
    close(writerObj);
end
end

