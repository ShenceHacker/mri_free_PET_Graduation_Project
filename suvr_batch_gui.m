function suvr_batch_gui
% 简易 GUI：跑 coreg+norm，然后批量 SUVR
% 依赖函数：
%   - run_coreg_norm_batch(MR_DIR, PET_DIR, OUT_DIR) -> 返回 wrpet 所在目录
%   - suvr_calc_5(petDir, voiPath, refs, outXlsxPath, 'MaskThreshold',x,'ResampleWithSPM',tf)

    % ---------- 基础 UI ----------
    fig = uifigure('Name','SUVR 批处理 GUI','Position',[100 100 880 560]);

    y = 500; h = 28; dy = 42; x1=20; x2=180; wEdit=560; wBtn=90;

    % 各路径输入 + 浏览按钮
    [eMR, bMR]       = addPathRow(fig, 'MR_DIR:',          x1,y, x2,wEdit,wBtn, true);   y=y-dy;
    [ePET, bPET]     = addPathRow(fig, 'PET_DIR:',         x1,y, x2,wEdit,wBtn, true);   y=y-dy;
    [eOUT, bOUT]     = addPathRow(fig, 'OUT_DIR:',         x1,y, x2,wEdit,wBtn, true);   y=y-dy;

    [eVOI, bVOI]     = addPathRow(fig, 'voiPath:',         x1,y, x2,wEdit,wBtn, false);  y=y-dy;
    [eCG,  bCG ]     = addPathRow(fig, 'CerebGrypath:',    x1,y, x2,wEdit,wBtn, false);  y=y-dy;
    [ePons,bPons]    = addPathRow(fig, 'Ponspath:',        x1,y, x2,wEdit,wBtn, false);  y=y-dy;
    [eWC,  bWC ]     = addPathRow(fig, 'WhlCblpath:',      x1,y, x2,wEdit,wBtn, false);  y=y-dy;
    [eWCB, bWCB]     = addPathRow(fig, 'WhlCblBrnStmpath:',x1,y, x2,wEdit,wBtn, false);  y=y-dy;

    [eXLSX,bXLSX]    = addSaveRow(fig, 'outXlsxPath:',     x1,y, x2,wEdit,wBtn);         y=y-dy;

    % 参数区
    uilabel(fig,'Position',[x1,y,150,h],'Text','MaskThreshold:');
    edtThr = uieditfield(fig,'numeric','Position',[x2,y,100,h],'Value',0.5,'Limits',[0,Inf]);
    cbSPM  = uicheckbox(fig,'Position',[x2+120,y,200,h],'Text','ResampleWithSPM','Value',true);
    y=y-dy;

    logArea = uitextarea(fig,'Position',[x1,y-160,840,150],'Editable','off','Value',{'准备就绪...'});
    y = y - 180;

    btnRun = uibutton(fig, ...
        'Text','▶ 开始运行', ...
        'FontSize',12, ...
        'FontWeight','bold', ...
        'BackgroundColor',[0.2 0.7 0.2], ...
        'FontColor',[1 1 1], ...
        'Position',[fig.Position(3)-160, 80, 140, 40], ... % ✅ 右下角
        'ButtonPushedFcn', @(~,~)onRun());

    % 绑定浏览按钮
    bMR.ButtonPushedFcn    = @(~,~) setDir(eMR);
    bPET.ButtonPushedFcn   = @(~,~) setDir(ePET);
    bOUT.ButtonPushedFcn   = @(~,~) setDir(eOUT);

    bVOI.ButtonPushedFcn   = @(~,~) setFile(eVOI, {'*.nii','NIfTI (*.nii)'});
    bCG.ButtonPushedFcn    = @(~,~) setFile(eCG,  {'*.nii','NIfTI (*.nii)'});
    bPons.ButtonPushedFcn  = @(~,~) setFile(ePons,{'*.nii','NIfTI (*.nii)'});
    bWC.ButtonPushedFcn    = @(~,~) setFile(eWC,  {'*.nii','NIfTI (*.nii)'});
    bWCB.ButtonPushedFcn   = @(~,~) setFile(eWCB, {'*.nii','NIfTI (*.nii)'});

    bXLSX.ButtonPushedFcn  = @(~,~) setSave(eXLSX, {'*.xlsx','Excel (*.xlsx)'}, 'suvr_results.xlsx');

    % ---------- 回调 ----------
    function onRun()
        btnRun.Enable = 'off';
        logmsg('开始运行...');

        try
            % 读取 UI 值
            MR_DIR  = strtrim(eMR.Value);
            PET_DIR = strtrim(ePET.Value);
            OUT_DIR = strtrim(eOUT.Value);

            voiPath = strtrim(eVOI.Value);
            CerebGrypath = strtrim(eCG.Value);
            Ponspath     = strtrim(ePons.Value);
            WhlCblpath   = strtrim(eWC.Value);
            WhlCblBrnStmpath = strtrim(eWCB.Value);

            outXlsxPath = strtrim(eXLSX.Value);

            % 基本校验
            mustFolder(MR_DIR,'MR_DIR');
            mustFolder(PET_DIR,'PET_DIR');
            mustFolder(OUT_DIR,'OUT_DIR');

            mustFile(voiPath,'voiPath');
            mustFile(CerebGrypath,'CerebGrypath');
            mustFile(Ponspath,'Ponspath');
            mustFile(WhlCblpath,'WhlCblpath');
            mustFile(WhlCblBrnStmpath,'WhlCblBrnStmpath');

            outDirParent = fileparts(outXlsxPath);
            if ~isempty(outDirParent) && ~isfolder(outDirParent), mkdir(outDirParent); end

            % 组 refs（注意你原始说明里 WhlCblpath 出现两次，这里只保留一次）
            refs = struct( ...
                'CerebGry',     CerebGrypath, ...
                'Pons',         Ponspath, ...
                'WhlCbl',       WhlCblpath, ...
                'WhlCblBrnStm', WhlCblBrnStmpath);

            % 运行 coreg+norm
            logmsg('调用 run_coreg_norm_batch ...');
            OUT_DIR2 = run_coreg_norm_batch(MR_DIR, PET_DIR, OUT_DIR);
            logmsg(['run_coreg_norm_batch 完成，wrpet 目录：' OUT_DIR2]);

            % 运行 SUVR
            thr = edtThr.Value;
            useSPM = cbSPM.Value;
            logmsg('开始批量 SUVR 计算 ...');
            suvr_calc_5(OUT_DIR2, voiPath, refs, outXlsxPath, ...
                        'MaskThreshold', thr, 'ResampleWithSPM', useSPM);

            logmsg('✅ 全部完成！');
            uialert(fig,'处理完成！','完成','Icon','success');
        catch ME
            logmsg(['❌ 出错：' ME.message]);
            uialert(fig, getReport(ME,'basic','hyperlinks','off'), '错误', 'Icon','error');
        end

        btnRun.Enable = 'on';
    end

    % ---------- 辅助函数 ----------
    function [edt, btn] = addPathRow(parent, label, x, y, x2, wEdit, wBtn, isDir)
        uilabel(parent,'Position',[x,y,150,h],'Text',label);
        edt = uieditfield(parent,'text','Position',[x2,y,wEdit,h]);
        if isDir
            btn = uibutton(parent,'Text','浏览','Position',[x2+wEdit+10,y,wBtn,h]);
        else
            btn = uibutton(parent,'Text','选择','Position',[x2+wEdit+10,y,wBtn,h]);
        end
    end

    function [edt, btn] = addSaveRow(parent, label, x, y, x2, wEdit, wBtn)
        uilabel(parent,'Position',[x,y,150,h],'Text',label);
        edt = uieditfield(parent,'text','Position',[x2,y,wEdit,h]);
        btn = uibutton(parent,'Text','保存到','Position',[x2+wEdit+10,y,wBtn,h]);
    end

    function setDir(edt)
        pth = uigetdir(pwd,'选择文件夹');
        if isequal(pth, 0)           % 用户取消
            return
        end
        if isstring(pth); pth = char(pth); end
        edt.Value = pth;
    end
    
    function setFile(edt, filter)
        [f, p] = uigetfile(filter, '选择文件');
        if isequal(f, 0)             % 用户取消
            return
        end
        fullpth = fullfile(p, f);
        if isstring(fullpth); fullpth = char(fullpth); end
        edt.Value = fullpth;
    end
    
    function setSave(edt, filter, def)
        [f, p] = uiputfile(filter, '保存结果为', def);
        if isequal(f, 0)             % 用户取消
            return
        end
        fullpth = fullfile(p, f);
        if isstring(fullpth); fullpth = char(fullpth); end
        edt.Value = fullpth;
    end


    function mustFolder(pth, name)
        if ~isfolder(pth), error('%s 不是有效文件夹：%s', name, pth); end
    end
    function mustFile(pth, name)
        if ~isfile(pth), error('%s 不是有效文件：%s', name, pth); end
    end

    function logmsg(s)
        % 统一把要写入的一行变成 char
        if isstring(s) || ischar(s)
            line = sprintf('%s  %s', datestr(now,'HH:MM:SS'), char(s));
        else
            % 如果传入的是结构/数值之类，转成可读文本
            line = sprintf('%s  %s', datestr(now,'HH:MM:SS'), strtrim(evalc('disp(s)')));
        end
    
        % 取出旧值，确保是元胞数组（字符向量）
        v = logArea.Value;
        if isstring(v), v = cellstr(v); end
        if ischar(v),   v = {v};        end
    
        % 追加并写回
        logArea.Value = [v; {line}];
        drawnow;
    end

end
