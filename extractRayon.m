% v2 modified by Baptiste Magnier
% Arthur Rubio, Lucas Riviere, 11/2023
% "Preprocessing of Iris Images for BSIF-Based Biometric Systems:
% Canny Algorithm and Iris Unwrapping", IPOL (Image Processing On Line), 2023, Paris, France.
%
% This code determines the inner and outer radius of the iris using edge detection
% The edge detection is performed using the Canny method
% Calculate the coordinates of the center of the image (which is considered for the moment as that of the eye)
%
% Input : I : image of the iris
% Output : r_ext : outer radius of the iris
%          r_int : inner radius of the iris
%          centre_oeil_x : x coordinate of the center of the image
%          centre_oeil_y : y coordinate of the center of the image

function [r_ext,r_int,centre_oeil_x,centre_oeil_y] = extractRayon(J)

s = size(J);
centreImageX = round(s(2)/2);
centreImageY = round(s(1)/2);

% noisy_img = f_addSaltPepperNoise(I, 0.05); % Ajouter le bruit

% Smoothing of the image
G = fspecial("gaussian", 25, 7);
I_gauss = conv2(J, G, "same");
% I_gauss_SP = conv2(noisy_img, G, "same");

% Definition of the masks
% SOBEL MASKS
Mx = [-1 0 1; -2 0 2; -1 0 1];
My = [1 2 1; 0 0 0; -1 -2 -1];
% Mx=[-1 0 1;-1 0 1;-1 0 1];
% My=[1 1 1;0 0 0;-1 -1 -1];

% Application des masques de Sobel
Jx = filter2(Mx, I_gauss);
Jy = filter2(My, I_gauss);
% Jx=filter2(-Mx,I_gauss)/6;
% Jy=filter2(-My,I_gauss)/6;

eta = atan2(Jy, Jx); % Utilisation de atan2 pour gérer correctement les quadrants
Ggray = sqrt(Jx.^2 + Jy.^2);
% eta = atan(Jy./Jx);
% Ggray=sqrt(Jx.*Jx + Jy.*Jy);

% figure,imagesc(J),colormap(gray), title('Image grey');
% figure,imagesc(Ggray),colormap(gray), title('Gradient grey');
% figure,imagesc(eta),colormap(gray), title('Gradient direction');

%%%%%%%%%% non maxima suppression

[NMS] =  directionalNMS(Jx,Jy);
Gradient_max= Ggray .* NMS;
% figure,imagesc(NMS),colormap(gray), title('NMS');

% figure,imagesc(Gradient_max), colormap(gray), title('Gradient max');

% Thresholding (slightly variable value depending on the image used)
Icol_suppr_n = f_normalisation(Gradient_max);
Icol_bin = Icol_suppr_n > 0.05 ;
% figure, imshow(Icol_bin, []);

[centers1, radii1, metric1, centers2, radii2, metric2] = detectCirclesWithDynamicSensitivity(Icol_bin);

% Invert the colors of the binarized image
Icol_bin_inverted = ~Icol_bin;

% Définir la taille de la marge (2 pixels)
taille_marge = 5;

% Obtenir les dimensions de l'image originale
[dimy, dimx] = size(Icol_bin_inverted);

% Calculer les dimensions de la nouvelle image avec la marge
nouvelle_dimy = dimy + 2 * taille_marge;
nouvelle_dimx = dimx + 2 * taille_marge;

% Créer une matrice noire de la nouvelle taille
image_avec_marge = zeros(nouvelle_dimy, nouvelle_dimx);

% Copier l'image originale au centre de la nouvelle matrice
image_avec_marge(taille_marge + 1:taille_marge + dimy, taille_marge + 1:taille_marge + dimx) = Icol_bin_inverted;
% figure,imagesc(image_avec_marge),colormap(gray),title("Inverted binarized image with margin");

function [centers1, radii1, metric1, centers2, radii2, metric2] = detectCirclesWithDynamicSensitivity(Icol_bin)
    % Initialiser les paramètres de sensibilité
    initialSensitivity = 0.859;  % Commencez avec une sensibilité plus basse
    maxSensitivity = 1.2;     % Sensibilité maximale à ne pas dépasser
    sensitivityStep = 0.02;    % Incrément de la sensibilité pour chaque itération

    % Détection pour le cercle iris/pupille
    [centers1, radii1, metric1] = tryFindCircles(Icol_bin, [20 80], 'bright', initialSensitivity, maxSensitivity, sensitivityStep);

    % Détection pour le cercle iris/sclère
    [centers2, radii2, metric2] = tryFindCircles(Icol_bin, [100 140], 'bright', initialSensitivity, maxSensitivity, sensitivityStep);
end

function [centers, radii, metric] = tryFindCircles(Icol_bin, radiusRange, objectPolarity, initialSensitivity, maxSensitivity, sensitivityStep)  
    sensitivity = initialSensitivity;
    centers = [];
    radii = [];
    metric = [];
    
    % Tant que la sensibilité ne dépasse pas le maximum et qu'aucun cercle n'a été détecté
    while isempty(centers) && sensitivity <= maxSensitivity
        [centers, radii, metric] = imfindcircles(Icol_bin, radiusRange, 'ObjectPolarity', objectPolarity, 'Sensitivity', sensitivity);
        
        % Augmenter la sensibilité pour la prochaine itération si aucun cercle n'est trouvé
        if isempty(centers)
            sensitivity = sensitivity + sensitivityStep;
        end
    end
    
    % Afficher un message si aucun cercle n'est détecté même à la sensibilité maximale
    if isempty(centers)
        fprintf('Aucun cercle trouvé même avec une sensibilité de %.2f\n', maxSensitivity);
    else
        fprintf('Cercles trouvés avec une sensibilité de %.2f\n', sensitivity);
    end
end

figure,imagesc(Icol_bin),colormap(gray),title("found circles");

% Initialisation des listes pour conserver les cercles filtrés
filteredCenters1 = [];
filteredRadii1 = [];
filteredMetric1 = [];
filteredCenters2 = [];
filteredRadii2 = [];
filteredMetric2 = [];

% Tolerance pour la comparaison des centres
tolerance = 5;

% Boucle à travers tous les cercles détectés pour trouver des centres similaires
if ~isempty(centers1) && ~isempty(centers2)
    for i = 1:size(centers1, 1)
        for j = 1:size(centers2, 1)
            if abs(centers1(i,1) - centers2(j,1)) <= tolerance && abs(centers1(i,2) - centers2(j,2)) <= tolerance
                % Ajoute les cercles correspondants aux listes filtrées
                filteredCenters1 = [filteredCenters1; centers1(i,:)];
                filteredRadii1 = [filteredRadii1; radii1(i)];
                filteredMetric1 = [filteredMetric1; metric1(i)];
                filteredCenters2 = [filteredCenters2; centers2(j,:)];
                filteredRadii2 = [filteredRadii2; radii2(j)];
                filteredMetric2 = [filteredMetric2; metric2(j)];
            end
        end
    end
end

% Après avoir trouvé tous les cercles
% Vérifie si filteredCenters1 contient 2 éléments ou plus
if size(filteredCenters1, 1) >= 2
    % Calcule les distances des centres filtrés au centre de l'image
    distances = sqrt((filteredCenters1(:,1) - centreImageX).^2 + (filteredCenters1(:,2) - centreImageY).^2);
    % Sélectionne l'indice du cercle le plus proche
    [~, closestIndex] = min(distances);
    % Met à jour filteredCenters1 et filteredRadii1 avec le cercle le plus proche
    filteredCenters1 = filteredCenters1(closestIndex, :);
    filteredRadii1 = filteredRadii1(closestIndex);
% Sinon, si filteredCenters1 est vide et centers1 n'est pas vide
elseif isempty(filteredCenters1) && ~isempty(centers1)
    % Calcule les distances de tous les centres dans centers1 au centre de l'image
    distances = sqrt((centers1(:,1) - centreImageX).^2 + (centers1(:,2) - centreImageY).^2);
    % Sélectionne l'indice du cercle le plus proche
    [~, closestIndex1] = min(distances);
    % Met à jour filteredCenters1 et filteredRadii1 avec le cercle le plus proche dans centers1
    filteredCenters1 = centers1(closestIndex1, :);
    filteredRadii1 = radii1(closestIndex1);
end

% Vérifie si filteredCenters2 contient 2 éléments ou plus
if size(filteredCenters2, 1) >= 2
    % Calcule les distances des centres filtrés au centre de l'image
    distances = sqrt((filteredCenters2(:,1) - centreImageX).^2 + (filteredCenters2(:,2) - centreImageY).^2);
    % Sélectionne l'indice du cercle le plus proche
    [~, closestIndex] = min(distances);
    % Met à jour filteredCenters2 et filteredRadii2 avec le cercle le plus proche
    filteredCenters2 = filteredCenters2(closestIndex, :);
    filteredRadii2 = filteredRadii2(closestIndex);
% Sinon, si filteredCenters2 est vide et centers2 n'est pas vide
elseif isempty(filteredCenters2) && ~isempty(centers2)
    % Calcule les distances de tous les centres dans centers2 au centre de l'image
    distances = sqrt((centers2(:,1) - centreImageX).^2 + (centers2(:,2) - centreImageY).^2);
    % Sélectionne l'indice du cercle le plus proche
    [~, closestIndex2] = min(distances);
    % Met à jour filteredCenters2 et filteredRadii2 avec le cercle le plus proche dans centers2
    filteredCenters2 = centers2(closestIndex2, :);
    filteredRadii2 = radii2(closestIndex2);
end

hold on;
% Vérification et affichage des cercles pour filteredCenters1
if ~isempty(filteredCenters1)
    viscircles(filteredCenters1, filteredRadii1, 'EdgeColor', 'b');
end

% Vérification et affichage des cercles pour filteredCenters2
if ~isempty(filteredCenters2)
    viscircles(filteredCenters2, filteredRadii2, 'EdgeColor', 'r');
end
hold off;

% Diameter calculation of the iris
centre_oeil_x = round(filteredCenters2(1,1));
centre_oeil_y = round(filteredCenters2(1,2));

% Radius calculation
r_int = round(filteredRadii1);  % Outer radius of the iris
r_ext = round(filteredRadii2);  % Inner radius of the iris
end