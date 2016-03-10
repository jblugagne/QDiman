function drawvalvesstates(valvesmatrix,xl)

vm = cat(1,[0 0 0],valvesmatrix);
cvm1 = cumsum(vm,1)./3600;
cvm2 = cumsum(vm,2);

figure(gcf)
hold on
for ind1 = 2:(size(vm,1))
    if vm(ind1,3) && cvm2(ind1,1)
        rectangle('Position',[cvm1(ind1-1,3) 0 cvm1(ind1,3) cvm2(ind1,1) ]','FaceColor','c','EdgeColor','none');
    end
    if vm(ind1,3) && cvm2(ind1,2)
        rectangle('Position',[cvm1(ind1-1,3) cvm2(ind1,1) cvm1(ind1,3) cvm2(ind1,2) ]','FaceColor','m','EdgeColor','none');
    end
    if vm(ind1,3) && cvm2(ind1,2) < 100
        rectangle('Position',[cvm1(ind1-1,3) cvm2(ind1,2) cvm1(ind1,3) 100 - cvm2(ind1,2)]','FaceColor',[.8 .8 .8],'EdgeColor','none');
    end
end



set(gcf,'Position',[10 10 750 200]);

set(gca,'Xcolor','w');
set(gca,'Ycolor','w');
set(gca,'XTick',[0 10 20 30 40 50 60 ]);
set(gca,'YTick',[0 25 50 75 100 ]);

xlim(xl)

    