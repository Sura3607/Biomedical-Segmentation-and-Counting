classdef RBCApp < matlab.apps.AppBase
    %RBCAPP App interface for RBC segmentation and counting.

    properties (Access = public)
        UIFigure matlab.ui.Figure
        LoadImageButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        ExportButton matlab.ui.control.Button
        SegmentationDropDown matlab.ui.control.DropDown
        CountingDropDown matlab.ui.control.DropDown
        KDropDown matlab.ui.control.DropDown
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
        FilteredSummary table
    end

    methods (Access = private)
        function startup(app)
            app.ProjectRoot = fileparts(mfilename("fullpath"));
            setupFinalPath(app.ProjectRoot);

            app.Config = config_default();
            app.ImagePath = char(app.Config.imagePath);
            app.Summary = table();
            app.FilteredSummary = table();

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
            app.FilteredSummary = table();
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

            selectedSegmentation = string(app.SegmentationDropDown.Value);
            includeKMeans = selectedSegmentation == "K-means" || selectedSegmentation == "Both";
            selectedK = str2double(app.KDropDown.Value);

            app.setBusy(true, "Running segmentation and RBC counting...");
            drawnow;

            try
                app.Config.imagePath = app.ImagePath;
                app.Config.groundTruth.rbcCount = lookupRBCGroundTruth(app.ImagePath, app.Config.metadataPath);
                app.Config.ml.kmeans.enabled = includeKMeans;
                app.Config.ml.kmeans.k = selectedK;
                app.Config.ml.kmeans.modelPath = "";

                app.Result = countRBCPipeline(app.ImagePath, app.Config);
                app.Summary = struct2table(app.Result.counts);
                app.FilteredSummary = app.filteredSummary();
                app.ResultsTable.Data = app.FilteredSummary;

                app.showImage(app.OriginalAxes, app.Result.original, "Original image");
                app.showSelectedSegmentationOverlays(selectedSegmentation);
                app.showSelectedCountOverlay();

                app.StatusLabel.Text = app.statusText();
            catch err
                app.StatusLabel.Text = "Pipeline failed.";
                uialert(app.UIFigure, err.message, "RBC pipeline error");
            end

            app.setBusy(false, app.StatusLabel.Text);
        end

        function exportResults(app)
            if isempty(app.FilteredSummary) || height(app.FilteredSummary) == 0
                uialert(app.UIFigure, "Run the pipeline before exporting.", "No results");
                return;
            end

            if ~isfolder(app.Config.outputDir)
                mkdir(app.Config.outputDir);
            end

            summaryPath = fullfile(app.Config.outputDir, "app_summary.csv");
            writetable(app.FilteredSummary, summaryPath);

            if isfield(app.Result, "overlays")
                selectedSegmentation = string(app.SegmentationDropDown.Value);
                if selectedSegmentation == "Algorithm" || selectedSegmentation == "Both"
                    imwrite(app.Result.overlays.algorithmMask, fullfile(app.Config.outputDir, "app_overlay_algorithm.png"));
                end
                if selectedSegmentation == "K-means" || selectedSegmentation == "Both"
                    imwrite(app.Result.overlays.kmeansMask, fullfile(app.Config.outputDir, "app_overlay_kmeans.png"));
                end
            end

            app.StatusLabel.Text = "Exported selected results to: " + string(app.Config.outputDir);
        end

        function summary = filteredSummary(app)
            summary = app.Summary;
            if isempty(summary) || height(summary) == 0
                return;
            end

            selectedSegmentation = string(app.SegmentationDropDown.Value);
            selectedCountingMethod = app.selectedCountingMethod();

            switch selectedSegmentation
                case "Algorithm"
                    keepSegmentation = summary.segmentation == "algorithm";
                case "K-means"
                    keepSegmentation = summary.segmentation == "kmeans";
                otherwise
                    keepSegmentation = summary.segmentation == "algorithm" | summary.segmentation == "kmeans";
            end

            keepCounting = summary.countingMethod == selectedCountingMethod;
            summary = summary(keepSegmentation & keepCounting, :);
        end

        function showSelectedSegmentationOverlays(app, selectedSegmentation)
            if selectedSegmentation == "Algorithm" || selectedSegmentation == "Both"
                app.showImage(app.AlgorithmAxes, app.Result.overlays.algorithmMask, "Algorithm RBC overlay");
            else
                cla(app.AlgorithmAxes);
                title(app.AlgorithmAxes, "Algorithm overlay");
            end

            if selectedSegmentation == "K-means" || selectedSegmentation == "Both"
                app.showImage(app.KMeansAxes, app.Result.overlays.kmeansMask, "K-means RBC overlay");
            else
                cla(app.KMeansAxes);
                title(app.KMeansAxes, "K-means overlay");
            end
        end

        function showSelectedCountOverlay(app)
            if ~isfield(app.Result, "overlays") || ~isfield(app.Result.overlays, "counts")
                cla(app.CountAxes);
                title(app.CountAxes, "Count overlay");
                return;
            end

            selectedSegmentation = string(app.SegmentationDropDown.Value);
            if selectedSegmentation == "Both"
                if any(app.FilteredSummary.segmentation == "kmeans")
                    selectedSegmentation = "kmeans";
                else
                    selectedSegmentation = "algorithm";
                end
            elseif selectedSegmentation == "K-means"
                selectedSegmentation = "kmeans";
            else
                selectedSegmentation = "algorithm";
            end

            fieldName = char(selectedSegmentation + "_" + app.selectedCountingField());
            if isfield(app.Result.overlays.counts, fieldName)
                app.showImage(app.CountAxes, app.Result.overlays.counts.(fieldName), strrep(fieldName, "_", " "));
            else
                cla(app.CountAxes);
                title(app.CountAxes, "Count overlay");
            end
        end

        function text = statusText(app)
            if isempty(app.FilteredSummary) || height(app.FilteredSummary) == 0
                text = "Done. No selected result rows.";
                return;
            end

            row = app.FilteredSummary(1, :);
            text = sprintf("Done. %s = %d RBC.", char(row.method), row.count);
            if height(app.FilteredSummary) > 1
                text = sprintf("Done. Showing %d selected result rows.", height(app.FilteredSummary));
            end
        end

        function method = selectedCountingMethod(app)
            switch string(app.CountingDropDown.Value)
                case "Connected components"
                    method = "connected_components";
                case "Watershed"
                    method = "watershed";
                otherwise
                    method = "area_estimate";
            end
        end

        function field = selectedCountingField(app)
            switch string(app.CountingDropDown.Value)
                case "Connected components"
                    field = "connectedComponents";
                case "Watershed"
                    field = "watershed";
                otherwise
                    field = "areaEstimate";
            end
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
            app.SegmentationDropDown.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.CountingDropDown.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.KDropDown.Enable = matlab.lang.OnOffSwitchState(~isBusy);
            app.StatusLabel.Text = message;
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure("Visible", "off");
            app.UIFigure.Name = "RBC Segmentation and Counting App";
            app.UIFigure.Position = [100 100 1280 760];

            mainGrid = uigridlayout(app.UIFigure, [4 1]);
            mainGrid.RowHeight = {76, 28, "1x", 210};
            mainGrid.ColumnWidth = {"1x"};
            mainGrid.Padding = [12 12 12 12];
            mainGrid.RowSpacing = 8;

            toolbar = uigridlayout(mainGrid, [2 8]);
            toolbar.Layout.Row = 1;
            toolbar.ColumnWidth = {120, 130, 120, 95, 145, 70, 70, "1x"};
            toolbar.RowHeight = {24, 34};
            toolbar.Padding = [0 0 0 0];

            app.LoadImageButton = uibutton(toolbar, "push");
            app.LoadImageButton.Text = "Load Image";
            app.LoadImageButton.Layout.Row = 2;
            app.LoadImageButton.Layout.Column = 1;
            app.LoadImageButton.ButtonPushedFcn = @(~, ~) app.loadImage();

            app.RunButton = uibutton(toolbar, "push");
            app.RunButton.Text = "Run Pipeline";
            app.RunButton.Layout.Row = 2;
            app.RunButton.Layout.Column = 2;
            app.RunButton.ButtonPushedFcn = @(~, ~) app.runPipeline();

            app.ExportButton = uibutton(toolbar, "push");
            app.ExportButton.Text = "Export CSV";
            app.ExportButton.Layout.Row = 2;
            app.ExportButton.Layout.Column = 3;
            app.ExportButton.ButtonPushedFcn = @(~, ~) app.exportResults();

            segmentationLabel = uilabel(toolbar, "Text", "Segmentation");
            segmentationLabel.Layout.Row = 1;
            segmentationLabel.Layout.Column = 4;
            app.SegmentationDropDown = uidropdown(toolbar);
            app.SegmentationDropDown.Items = ["Algorithm", "K-means", "Both"];
            app.SegmentationDropDown.Value = "Both";
            app.SegmentationDropDown.Layout.Row = 2;
            app.SegmentationDropDown.Layout.Column = 4;

            countingLabel = uilabel(toolbar, "Text", "Counting");
            countingLabel.Layout.Row = 1;
            countingLabel.Layout.Column = 5;
            app.CountingDropDown = uidropdown(toolbar);
            app.CountingDropDown.Items = ["Connected components", "Watershed", "Area estimate"];
            app.CountingDropDown.Value = "Watershed";
            app.CountingDropDown.Layout.Row = 2;
            app.CountingDropDown.Layout.Column = 5;

            kLabel = uilabel(toolbar, "Text", "K");
            kLabel.Layout.Row = 1;
            kLabel.Layout.Column = 6;
            app.KDropDown = uidropdown(toolbar);
            app.KDropDown.Items = ["2", "3", "4", "5"];
            app.KDropDown.Value = "3";
            app.KDropDown.Layout.Row = 2;
            app.KDropDown.Layout.Column = 6;

            app.ImagePathLabel = uilabel(toolbar);
            app.ImagePathLabel.Text = "";
            app.ImagePathLabel.WordWrap = "on";
            app.ImagePathLabel.Layout.Row = [1 2];
            app.ImagePathLabel.Layout.Column = [7 8];

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
