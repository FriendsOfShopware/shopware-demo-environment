async function getMatrix() {
    const data = {
        'fail-fast': false,
        matrix: {
            include: []
        }
    };

    // Helper function to compare versions
    function versionCompare(a, b) {
        const aParts = a.split('.').map(Number);
        const bParts = b.split('.').map(Number);
        
        for (let i = 0; i < Math.max(aParts.length, bParts.length); i++) {
            const aPart = aParts[i] || 0;
            const bPart = bParts[i] || 0;
            
            if (aPart > bPart) return true;
            if (aPart < bPart) return false;
        }
        return true;
    }

    try {
        // Fetch PHP version data
        const response = await fetch('https://raw.githubusercontent.com/FriendsOfShopware/shopware-static-data/main/data/php-version.json');
        const phpVersionData = await response.json();

        // Transform the data
        const versions = Object.entries(phpVersionData)
            .map(([key, value]) => {
                const versionSplit = key.split('.');
                const version = [versionSplit[0], versionSplit[1], versionSplit[2]].join('.');
                
                return {
                    phpVersion: value,
                    shopwareVersion: key.toLowerCase(),
                    minorShopwareVersion: version
                };
            })
            .reverse()
            .filter(item => versionCompare(item.shopwareVersion, '6.6.10'));

        // Remove duplicates by minorShopwareVersion, preferring stable versions
        const uniqueVersions = versions.reduce((acc, item) => {
            const existingIndex = acc.findIndex(v => v.minorShopwareVersion === item.minorShopwareVersion);
            
            if (existingIndex === -1) {
                acc.push(item);
            } else {
                // Prefer stable versions over RC versions
                const existing = acc[existingIndex];
                const isExistingRC = existing.shopwareVersion.includes('-rc');
                const isCurrentRC = item.shopwareVersion.includes('-rc');
                
                if (isExistingRC && !isCurrentRC) {
                    // Replace RC with stable version
                    acc[existingIndex] = item;
                }
            }
            
            return acc;
        }, []);

        data.matrix.include = uniqueVersions;

        return JSON.stringify(data, null, 2);
    } catch (error) {
        console.error('Error fetching or processing data:', error);
        throw error;
    }
}

// Execute and print result
getMatrix().then(result => {
    console.log(result);
}).catch(error => {
    console.error('Failed to generate matrix:', error);
    process.exit(1);
});