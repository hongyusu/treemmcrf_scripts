

function rtn = plotData(X,Y,eta1,eta2,r,c,n,tl)

    for i=1:size(Y,2)/2
        subplot(r,c,n+i)
        k=(i-1)*2+1;
        a=X(find(Y(:,k)==1&Y(:,k+1)==1),:);plot(a(:,2),a(:,1),'b.','markersize',3);
        if i==2
            title(sprintf('%s\ny%d,y%d',tl,k,k+1));
        else
            title(sprintf('y%d,y%d',k,k+1));
        end
            axis equal;
        hold on
        a=X(find(Y(:,k)==0&Y(:,k+1)==0),:);plot(a(:,2),a(:,1),'r.','markersize',3);
        hold on
        a=X(find(Y(:,k)==0&Y(:,k+1)==1),:);plot(a(:,2),a(:,1),'g.','markersize',3);
        hold on
        a=X(find(Y(:,k)==1&Y(:,k+1)==0),:);plot(a(:,2),a(:,1),'m.','markersize',3);
        hold on
        D=getPlotData(eta1(i,:));
        plot(D(:,2),D(:,1),'k','LineWidth',1.5)
        hold on
        D=getPlotData(eta2(i,:));
        plot(D(:,2),D(:,1),'k','LineWidth',1.5)
        hold off
    end

end

function D = getPlotData(eta)
    D = [];
    for i=-0.99:0.01:0.99
        D=[D;[i,-eta(1)*i-eta(3)]];
    end
    D=D(find(D(:,2)>-0.8 & D(:,2)<0.8),:);
end