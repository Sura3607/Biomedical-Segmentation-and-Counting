classdef RBCApp < matlab.apps.AppBase
    %RBCAPP Simple App Designer-style interface for the RBC demo.

    properties (Access = public)
        UIFigure matlab.ui.Figure
        LoadImageButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        ImagePathLabel matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label
        OriginalAxes matlab.ui.control.UIAxes
        AlgorithmAxes matlab.ui.control.UIAxes
        KMeansAxes matlab.ui.control.UIAxes
        CountAxes matlab.ui.control.UIAxes
        ResultsTable matlab.ui.control.Table
    end

    properties (Access = private)
        ProjectRoot char
        Config struct
        ImagePath char
        Result struct
        Summary table
    end

    methods (Access = private)
        function startup(app)
            app.ProjectRoot = fileparts(mfilename("fullpath"));
            setupFinalPath(app.ProjectRoot);

            app.Config = config_default();
            app.ImagePath = char(app.Config.imagePath);
            app.Summary = table();

            app.ImagePathLabel.Text = app.ImagePath;
            app.StatusLabel.Text = "Ready. Load an image or run the default sample.";

            app.clearAxes();
            if isfile(app.ImagePath)
                app.showImage(app.OriginalAxes, imread(app.ImagePath), "Original image");
            end
        end

        function loadImage(app)
            [fileName, folderName] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image files'}, ...
                'Choose blood smear image', app.ProjectRoot);

            if isequal(fileName, 0)
                return;
            end

            app.ImagePath = fullfile(folderName, fileName);
            app.ImagePathLabel.Text = app.ImagePath;
            app.Result = struct();
            app.Summary = table();
            app.ResultsTable.Data = table();
            app.StatusLabel.Text = "Image loaded. Press Run Pipeline.";

            app.clearAxes();
            app.showImage(app.OriginalAxes, imread(app.ImagePath), "Original image");
        end

        function runPipeline(app)
            if isempty(app.ImagePath) || ~isfile(app.ImagePath)
                uialert(app.UIFigure, "Please choose a valid image first.", "Missing image");
                return;
            end

            app.setBusy(true, "Running segmentation and RBC counting...");
            drawnow;

            try
                app.Config.imagePath = app.ImagePath;
                app.Result = countRBCPipeline(app.ImagePath, app.Config);
                app.Summary = struct2table(app.Result.counts);

                app.ResultsTable.Data = app.Summary;
                app.showImage(app.OriginalAxes, app.Result.original, "Original image");
                app.showImage(app.AlgorithmAxes, app.Result.overlays.algorithmMask, "Algorithm RBC overlay");
                app.showImage(app.KMeansAxes, app.Result.overlays.kmeansMask, "K-means RBC overlay");
                app.showBestCountOverlay();

                bestRow = app.bestSummaryRow();
                app.StatusLabel.Text = sprintf("Done. Best demo result: %s = %d RBC.", ...
                    char(bestRow.method), bestRow.count);
            catch err
                app.StatusLabel.Text = "Pipeline failed.";
                uialert(app.UIFigure, err.message, "RBC pipeline error");
            end

            app.setBusy(false, app.StatusLabel.Text);
        end

        function exportResults(app)
            if isempty(app.Summary) || height(app.Summary) == 0
                uialert(app.UIFigure, "Run the pipeline before exporting.", "No results");
                return;
            end

            if ~isfolder(app.Config.outputDir)
                mkdir(app.Config.outputDir);
            end

            summaryPath = fullfile(app.Config.outputDir, "app_summary.csv");
            writetable(app.Summary, summaryPath);

            if isfield(app.Result, "overlays")
                imwrite(app.Result.overlays.algorithmMask, fullfile(app.Config.outputDir, "app_overlay_algorithm.png"));
                imwrite(app.Result.overlays.kmeansMask, fullfile(app.Config.outputDir, "app_overlay_kmeans.png"));
            end

            app.StatusLabel.Text = "Exported results to: " + string(app.Config.outputDir);
        end

        function showBestCountOverlay(app)
            if ~isfield(app.Result, "overlays") || ~isfield(app.Result.overlays, "counts")
                cla(app.CountAxes);
                title(app.CountAxes, "Count overlay");
                return;
            end

            overlay = [];
            overlayTitle = "Count overlay";

            if isfield(app.Result.overlays.counts, "kmeans_watershed")
                overlay = app.Result.overlays.counts.kmeans_watershed;
                overlayTitle = "K-means watershed count";
            elseif isfield(app.Result.overlays.counts, "algorithm_watershed")
                overlay = app.Result.overlays.counts.algorithm_watershed;
                overlayTitle = "Algorithm watershed count";
            else
                names = fieldnames(app.Result.overlays.counts);
                if ~isempty(names)
                    overlay = app.Result.overlays.counts.(names{1});
                    overlayTitle = strrep(names{1}, "_", " ");
                end
            end

            if isempty(overlay)
                cla(app.CountAxes);
                title(app.CountAxes, overlayTitle);
            else
                app.showImage(app.CountAxes, overlay, overlayTitle);
            end
        end

        function row = bestSummaryRow(app)
            if isempty(app.Summary) || height(app.Summary) == 0
                row = table();
                return;
            end

            preferredMethod = "kmeans_watershed";
            idx = find(app.Summary.method == preferredMethod, 1);
            if isempty(idx)
                idx = 1;
            end
            row = app.Summary(idx, :);
        end

        function showImage(~, ax, img, titleText)
            imshow(img, "Parent", ax);
            title(ax, titleText);
            ax.XTick = [];
            ax.YTick = [];
        end

        function clearAxes(app)
            axesList = [app.OriginalAxes, app.AlgorithmAxes, app.KMeansAxes, app.CountAxes];
            titles = ["Original image", "Algorithm overlay", "K-means overlay", "Count overlay"];

            for i = 1:numel(axesList)
                cla(axesList(i));
                title(axesList(i), titles(i));
                axesList(i).XTick = [];
                axesList(i).YTick = [];
                axesList(i).Box = "on";
            end
        end

        function setBusy(app, isBusy, message)
            app.LoadImageButton.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.RunButton.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.ExportButton.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.StatusLabel.Text = message;
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure("Visible", "off");
            app.UIFigure.Name = "RBC Segmentation and Counting App";
            app.UIFigure.Position = [100 100 1180 720];

            mainGrid = uigridlayout(app.UIFigure, [4 1]);
            mainGrid.RowHeight = {48, 28, "1x", 210};
            mainGrid.ColumnWidth = {"1x"};
            mainGrid.Padding = [12 12 12 12];
            mainGrid.RowSpacing = 8;

            toolbar = uigridlayout(mainGrid, [1 4]);
            toolbar.Layout.Row = 1;
            toolbar.ColumnWidth = {120, 130, 120, "1x"};
            toolbar.RowHeight = {"1x"};
            toolbar.Padding = [0 0 0 0];

            app.LoadImageButton = uibutton(toolbar, "push");
            app.LoadImageButton.Text = "Load Image";
            app.LoadImageButton.ButtonPushedFcn = @(~, ~) app.loadImage();

            app.RunButton = uibutton(toolbar, "push");
            app.RunButton.Text = "Run Pipeline";
            app.RunButton.ButtonPushedFcn = @(~, ~) app.runPipeline();

            app.ExportButton = uibutton(toolbar, "push");
            app.ExportButton.Text = "Export CSV";
            app.ExportButton.ButtonPushedFcn = @(~, ~) app.exportResults();

            app.ImagePathLabel = uilabel(toolbar);
            app.ImagePathLabel.Text = "";
            app.ImagePathLabel.WordWrap = "on";

            app.StatusLabel = uilabel(mainGrid);
            app.StatusLabel.Layout.Row = 2;
            app.StatusLabel.Text = "Ready.";

            imageGrid = uigridlayout(mainGrid, [2 2]);
            imageGrid.Layout.Row = 3;
            imageGrid.ColumnWidth = {"1x", "1x"};
            imageGrid.RowHeight = {"1x", "1x"};
            imageGrid.Padding = [0 0 0 0];

            app.OriginalAxes = uiaxes(imageGrid);
            app.OriginalAxes.Layout.Row = 1;
            app.OriginalAxes.Layout.Column = 1;

            app.AlgorithmAxes = uiaxes(imageGrid);
            app.AlgorithmAxes.Layout.Row = 1;
            app.AlgorithmAxes.Layout.Column = 2;

            app.KMeansAxes = uiaxes(imageGrid);
            app.KMeansAxes.Layout.Row = 2;
            app.KMeansAxes.Layout.Column = 1;

            app.CountAxes = uiaxes(imageGrid);
            app.CountAxes.Layout.Row = 2;
            app.CountAxes.Layout.Column = 2;

            app.ResultsTable = uitable(mainGrid);
            app.ResultsTable.Layout.Row = 4;
            app.ResultsTable.Data = table();

            app.UIFigure.Visible = "on";
        end
    end

    methods (Access = public)
        function app = RBCApp
            createComponents(app);
            registerApp(app, app.UIFigure);
            runStartupFcn(app, @(app) startup(app));

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
