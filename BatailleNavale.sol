// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BatailleNavale {
    // VARIABLES
    address public hote; // Adresse du joueur qui a créé la partie
    address public invite; // Adresse du joueur invité
    address public gagnant; // Adresse du joueur gagnant
    address public AQuiLeTour; // Adresse du joueur dont c'est le tour
    bool public PartieStart; // Indique si la partie a commencé
    bool public partieTerminee; // Indique si la partie est terminée
    bool public hoteAParie; // Indique si le joueur hôte a misé
    bool public inviteAParie; // Indique si le joueur invité a misé
    uint256 public montantPari; // Montant total misé pour la partie
    mapping(address => Coordonnees[]) public historiqueAttaque; // Historique des attaques pour chaque joueur
    mapping(address => mapping(uint8 => mapping(uint8 => CoordinateStatus))) public historiqueAttaqueStatus;
    mapping(address => AttaqueTemporaire) attaquesTemporaires;

    enum CoordinateStatus {
        Rater, // Status indiquant une attaque ratée
        Toucher, // Status indiquant une attaque réussie
        Couler // Status indiquant un navire coulé
    }
struct AttaqueTemporaire {
    uint8 x;
    uint8 y;
}
    struct Coordonnees {
        uint8 x; // Coordonnée x de l'attaque
        uint8 y; // Coordonnée y de l'attaque
        CoordinateStatus status; // Status de l'attaque
    }

    event partieCommencee(address hote, address invite); // Événement déclenché lorsque la partie commence
    event PartieTerminee(address gagnant); // Événement déclenché lorsque la partie est terminée avec un gagnant
    event Attack(address indexed attacker, uint8 x, uint8 y); // Événement déclenché lors d'une attaque
    event PariEffectue(address parieur, uint256 montant); // Événement déclenché lorsqu'un joueur place une mise

    constructor() {
        hote = msg.sender; // Initialise l'adresse du joueur hôte avec l'adresse de déploiement du contrat
        PartieStart = false; // La partie n'a pas encore commencé lors de la création du contrat
        partieTerminee = false; // La partie n'est pas encore terminée lors de la création du contrat
        montantPari = 0; // Initialise le montant total de la mise à 0
        // Initialise les variables booléennes à false
        hoteAParie = false;
        inviteAParie = false;
    }

    modifier onlyPlayers() {
        require(msg.sender == hote || msg.sender == invite, "Vous ne jouez pas cette partie."); // Vérifie si l'appelant est un joueur de la partie
        _;
    }

    modifier gameNotStarted() {
        require(!PartieStart, "La partie a deja demarre."); // Vérifie si la partie n'a pas encore commencé
        _;
    }

    modifier gameStartedOnly() {
        require(PartieStart, "La partie n'a pas encore commence."); // Vérifie si la partie a commencé
        _;
    }

    modifier gameNotOver() {
        require(!partieTerminee, "La partie est terminee."); // Vérifie si la partie n'est pas terminée
        _;
    }

    modifier validCoordinate(uint8 _x, uint8 _y) {
        require(_x >= 0 && _x < 10, "Coordonnee x incorrecte."); // Vérifie si la coordonnée x est valide
        require(_y >= 0 && _y < 10, "Coordonnee y incorrecte."); // Vérifie si la coordonnée y est valide
        _;
    }

    modifier isCurrentPlayer(address player) {
        require(player == AQuiLeTour, "Ce n'est pas votre tour.");
        _;
    }

    modifier isNotCurrentPlayer(address player) {
    require(player != AQuiLeTour, "Seul le qui est joueur attaque peut definir le status de la case ciblee.");
    _;
}

    function inviterJoueur(address _invite) external gameNotStarted {
        require(msg.sender == hote, "Seul le proprietaire peut inviter un joueur."); // Vérifie si l'appelant est le joueur hôte
        invite = _invite; // Invite le joueur avec l'adresse spécifiée
    }

    function startGame() external gameNotStarted {
        require(msg.sender == hote, "Seul le proprietaire peut demarrer la partie."); // Vérifie si l'appelant est le joueur hôte
        require(invite != address(0), "Veuillez d'abord inviter un joueur."); // Vérifie si un joueur a été invité
        require(hoteAParie && inviteAParie, "Les deux joueurs doivent parier avant de demarrer la partie."); // Vérifie si les deux joueurs ont misé avant de commencer la partie

        PartieStart = true; // Marque le début de la partie
        AQuiLeTour = invite; // Initialise le tour au joueur invité
        emit partieCommencee(hote, invite); // Déclenche l'événement de début de partie
    }

    function parier(uint8 _montantParis) external payable gameNotStarted onlyPlayers {
        require(msg.value == 0, "Ne specifiez pas de valeur dans la transaction, le montant est determine par l'argument _montantParis."); // Vérifie si aucun ether n'a été envoyé avec la transaction, le montant est déterminé par l'argument _montantParis
        
        montantPari += _montantParis; // Ajoute le montant de la mise au montant total misé
        emit PariEffectue(msg.sender, _montantParis); // Déclenche l'événement de mise effectuée
        
        // Marque le joueur actuel comme ayant effectué un pari
        if (msg.sender == hote) {
            hoteAParie = true; // Marque le joueur hôte comme ayant misé
        } else if (msg.sender == invite) {
            inviteAParie = true; // Marque le joueur invité comme ayant misé
        }
    }

function attack(uint8 _x, uint8 _y) external onlyPlayers gameStartedOnly gameNotOver isCurrentPlayer(msg.sender) validCoordinate(_x, _y) {
    // Stockage temporaire des coordonnées de l'attaque
    attaquesTemporaires[msg.sender] = AttaqueTemporaire(_x, _y);
    emit Attack(msg.sender, _x, _y); // Émet seulement les coordonnées de l'attaque
}


function declarerEtatCase(uint8 _x, uint8 _y, CoordinateStatus _status) external onlyPlayers gameStartedOnly gameNotOver isNotCurrentPlayer(msg.sender) {
    require(attaquesTemporaires[AQuiLeTour].x != 0 && attaquesTemporaires[AQuiLeTour].y != 0, "Le joueur a qui c'est le tour n'a pas encore attaque.");

    // Accéder aux coordonnées de l'attaque depuis le stockage temporaire
    uint8 xAttaque = attaquesTemporaires[AQuiLeTour].x;
    uint8 yAttaque = attaquesTemporaires[AQuiLeTour].y;
    
    // Vérifier que les coordonnées fournies correspondent à l'attaque précédente
    require(_x == xAttaque && _y == yAttaque, "Les coordonnees de la case ne correspondent pas a l'attaque precedente.");
    
    // Vérifier que le joueur attaqué est celui qui appelle la fonction
    require(msg.sender == invite || msg.sender == hote, "Vous n'etes pas autorise a declarer l'etat de cette case.");

    // Enregistrement de l'état de la case dans l'historique des attaques du joueur attaqué
    historiqueAttaque[AQuiLeTour].push(Coordonnees(xAttaque, yAttaque, _status));

    // Vérifie si la partie est terminée après l'attaque
    checkGameOver();

    // Change de joueur
    if (AQuiLeTour == hote) {
        AQuiLeTour = invite;
    } else {
        AQuiLeTour = hote;
    }
}
    function checkGameOver() internal {
        uint8 nbCoules = 0; // Nombre de navires coulés
        uint8 nbTouches = 0; // Nombre d'attaques réussies
        for (uint i = 0; i < historiqueAttaque[msg.sender].length; i++) {
            if (historiqueAttaque[msg.sender][i].status == CoordinateStatus.Couler) {
                nbCoules++; // Incrémente le nombre de navires coulés
            }
            if (historiqueAttaque[msg.sender][i].status == CoordinateStatus.Toucher) {
                nbTouches++; // Incrémente le nombre d'attaques réussies
            }
        }
        if (nbCoules == 5 && nbTouches == 12) { // Vérifie si tous les navires ont été coulés et si toutes les attaques ont touché
            partieTerminee = true; // Marque la partie comme terminée
            gagnant = msg.sender; // Enregistre le joueur actuel comme gagnant
            emit PartieTerminee(msg.sender); // Déclenche l'événement de fin de partie avec un gagnant
        }
    }

    function listeAttaques(address _joueur) external view onlyPlayers returns (Coordonnees[] memory) {
        return historiqueAttaque[_joueur]; // Renvoie l'historique des attaques d'un joueur
    }

        // Fonction de récupération des fonds
     function recupererGain() external gameStartedOnly gameNotOver {
        require(partieTerminee, "La partie n'est pas encore terminee."); // Vérifie si la partie est terminée
        require(msg.sender == gagnant, "Seul le gagnant peut recuperer le gain."); // Vérifie si l'appelant est le joueur gagnant
        
        uint256 gain = montantPari; // Stocke le montant total misé comme gain
        montantPari = 0; // Réinitialise le montant total misé à 0
        
        payable(gagnant).transfer(gain); // Transfère le gain au joueur gagnant
    }
}
