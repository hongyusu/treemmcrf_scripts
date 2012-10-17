function checkDistribution(Y)

    d=[];
    for i=1:(size(Y,2)-1)
        for j=(i+1):size(Y,2)
            tmpY=Y(:,[i,j]);
            d=[d;[i,j,sum(sum(tmpY))/size(Y,1)/2,abs(corr(tmpY(:,1),tmpY(:,2)))]];
        end
    end
    d(:,3)=min(d(:,3),1-d(:,3));
    d(:,3:4)=ceil(100*d(:,3:4));
    
    m=zeros(50,100);
    for i=1:50
        for j=1:100
            m(i,j)=size(d(find(and(d(:,3)==i,d(:,4)==j)),:),1);
        end
    end
    
    imagesc(m)
    
end