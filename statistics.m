clc;                  % Clear command window.
clear all;            % Remove items from workspace, freeing up system memory
close all;            % Close all figures

%% Load the selected domain-specific filter set
l = 15;     % size of the filer
n = 7;      % number of kernels in a set
filters = ['./iris_sourced_filters/new_bsif_filters_based_on_eyetracker_data/ICAtextureFilters_' num2str(l) 'x' num2str(l) '_' num2str(n) 'bit.mat'];
load(filters);

scoresGenuine = [];
scoresImpostor = [];

% Specify the path to the CSV file
fileCSVTrue = 'WACV_2019_Czajka_etal_Stest_GENUINE.csv';
fileCSVFalse = 'WACV_2019_Czajka_etal_Stest_IMPOSTOR.csv';

% Load both csv files in a Matlab table
CSVTrue = readtable(fileCSVTrue);
CSVFalse = readtable(fileCSVFalse);

% Get the total number of rows in the file
numRowsTrue = size(CSVTrue, 1);
numRowsFalse = size(CSVFalse, 1);
nanCounterTrue = 0;
nanCounterFalse = 0;

% Iterate over each row in the Genuine Excel
for i = 2:numRowsTrue
    % Access the data of row i
    cellTrue1 = string(CSVTrue{i,1});
    cellTrue2 = string(CSVTrue{i,2});
    % Remove the .tiff extension from the file names
    cellTrue1 = erase(cellTrue1, ".tiff");
    cellTrue2 = erase(cellTrue2, ".tiff");
    imTrue1 = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/DB_bmp/' + cellTrue1 + '.bmp']) + eps;
    imTrue2 = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/DB_bmp/' + cellTrue2 + '.bmp']) + eps;
    codesTrue1(:,:,:,i) = extractCode(imTrue1,ICAtextureFilters);
    codesTrue2(:,:,:,i) = extractCode(imTrue2,ICAtextureFilters);
    masksTrue1(:,:,i) = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/Masks_bmp/' + cellTrue1 + '_mask.bmp']) + eps;
    masksTrue2(:,:,i) = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/Masks_bmp/' + cellTrue2 + '_mask.bmp']) + eps;

    scoreG = matchCodes(codesTrue1(:,:,:,i),codesTrue2(:,:,:,i),masksTrue1(:,:,i),masksTrue2(:,:,i),l);
    disp(['genuine comparison score = ' num2str(scoreG)])
    if isnan(scoreG)
        nanCounterTrue = nanCounterTrue + 1;
    else
        scoresGenuine = [scoresGenuine, scoreG];
    end
end

% Iterate over each row in the Impostor Excel
for i = 2:numRowsFalse
    % Access the data of row i
    cellFalse1 = string(CSVFalse{i,1});
    cellFalse2 = string(CSVFalse{i,2});
    % Remove the .tiff extension from the file names
    cellFalse1 = erase(cellFalse1, ".tiff");
    cellFalse2 = erase(cellFalse2, ".tiff");
    imFalse1 = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/DB_bmp/' + cellFalse1 + '.bmp']) + eps;
    imFalse2 = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/DB_bmp/' + cellFalse2 + '.bmp']) + eps;
    codesFalse1(:,:,:,i) = extractCode(imFalse1,ICAtextureFilters);
    codesFalse2(:,:,:,i) = extractCode(imFalse2,ICAtextureFilters);
    masksFalse1(:,:,i) = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/Masks_bmp/' + cellFalse1 + '_mask.bmp']) + eps;
    masksFalse2(:,:,i) = imread(['D:/Prive/Code/BSIF-iris/Unwrapped_DB/Masks_bmp/' + cellFalse2 + '_mask.bmp']) + eps;

    scoreI = matchCodes(codesFalse1(:,:,:,i),codesFalse2(:,:,:,i),masksFalse1(:,:,i),masksFalse2(:,:,i),l);
    disp(['impostor comparison score = ' num2str(scoreI)])
    if isnan(scoreI)
        nanCounterFalse = nanCounterFalse + 1;
    else
        scoresImpostor = [scoresImpostor, scoreI];
    end
end

% Calcul des statistiques pour les scores genuine
meanGenuine = mean(scoresGenuine);
stdDevGenuine = std(scoresGenuine);
varianceGenuine = var(scoresGenuine);

% Calcul des statistiques pour les scores impostor
meanImpostor = mean(scoresImpostor);
stdDevImpostor = std(scoresImpostor);
varianceImpostor = var(scoresImpostor);

% Calcul de l'erreur en % pour les scores genuine et impostor
errorGenuine = sum(scoresGenuine > 0.3875) / numel(scoresGenuine) * 100;
errorImpostor = sum(scoresImpostor < 0.3875) / numel(scoresImpostor) * 100;

% Calcul du pourcentage de NaN
percentNanGenuine = nanCounterTrue / (numRowsTrue - 1) * 100;
percentNanImpostor = nanCounterFalse / (numRowsFalse - 1) * 100;

% Création des variables pour le tableau
Mean = [meanGenuine; meanImpostor];
StandardDeviation = [stdDevGenuine; stdDevImpostor];
Variance = [varianceGenuine; varianceImpostor];
ErrorPercent = [errorGenuine; errorImpostor];
PercentNaN = [percentNanGenuine; percentNanImpostor];

% Création du tableau
StatsTable = table(Mean, StandardDeviation, Variance, ErrorPercent, PercentNaN, 'RowNames', {'Genuine', 'Impostor'});

% Affichage du tableau
disp(StatsTable);

figure; % Ouvre une nouvelle figure
hold on; % Permet de superposer plusieurs graphiques
% Génère des valeurs x constantes avec un léger décalage pour chaque ensemble
xGenuine = 1; % Position x constante pour les scores genuine
xImpostor = 2; % Position x constante pour les scores impostor

% Utilise scatter pour afficher les scores
scatter(xGenuine*ones(size(scoresGenuine)), scoresGenuine, 'b', 'DisplayName', 'Genuine');
scatter(xImpostor*ones(size(scoresImpostor)), scoresImpostor, 'r', 'DisplayName', 'Impostor');
% Met à jour les étiquettes des axes
xlabel('Type');
ylabel('Score');

% Affiche la légende
legend('show');
% Définit le titre du graphique
title('Répartition des scores Genuine et Impostor');
hold off; % Termine le mode superposition