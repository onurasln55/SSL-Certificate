#!/bin/bash
 
# Kullanım: ./a-sertifika_istegi_olustur.sh domain [san1 san2 san3 ...]

function show_help() {
    echo "Kullanım: $0 [domain] [SAN1 SAN2 ...]"
    echo "Bu script belirtilen domain için gerekli sertifika dosyalarını oluşturur."
    echo -e "\nSeçenekler:"
    echo "  -h, --help    Yardım mesajını gösterir."
    echo "  - Birden fazla SAN belirtmek için boşluk ile ayırarak girin."
    echo "  Örnek: ./a-sertifika_istegi_olustur.sh example.com sub.example.com 192.168.1.1"
    exit 0
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

echo "[+] Başlatılıyor..."
year=$(date +%Y)

domain="$1"
shift  # İlk parametreyi (domain) aldık, geriye SAN'lar kaldı

if [ -z "$domain" ]; then
    echo "[-] Lütfen bir domain adı belirtin!"
    exit 1
fi

# Eğer domain '*' ile başlıyorsa, 'wildcard' olarak değiştir
if [[ "$domain" == \** ]]; then
    safe_domain="wildcard${domain:1}"
else
    safe_domain="$domain"
fi

echo "[+] Klasör oluşturuluyor: $safe_domain/$year"
mkdir -p "$safe_domain/$year"

# SAN listesi varsa ayıralım
dns_list=()
ip_list=()

for san in "$@"; do
    if [[ "$san" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ip_list+=("$san")  # Eğer IP formatında ise ip_list'e ekle
    else
        dns_list+=("$san") # Değilse DNS olarak ekle
    fi
done

# SAN kullanılacak mı kontrol edelim
if [ ${#dns_list[@]} -eq 0 ] && [ ${#ip_list[@]} -eq 0 ]; then
    echo "[+] SAN bilgisi belirtilmedi, SAN'sız işlem yapılacak."
    cat <<EOL > "$safe_domain/$year/san.cnf"
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
stateOrProvinceName         = State or Province Name (full name)
localityName               = Locality Name (eg, city)
organizationName           = Organization Name (eg, company)
commonName                 = $domain
EOL
else
    echo "[+] SAN bilgisi mevcut, san.cnf oluşturuluyor..."
    cat <<EOL > "$safe_domain/$year/san.cnf"
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext
[ req_distinguished_name ]
countryName                 = Country Name (2 letter code)
stateOrProvinceName         = State or Province Name (full name)
localityName               = Locality Name (eg, city)
organizationName           = Organization Name (eg, company)
commonName                 =  Common Name
[ req_ext ]
subjectAltName = @alt_names
[alt_names]
EOL

    # DNS ekleme
    dns_counter=1
    for dns in "${dns_list[@]}"; do
        echo "DNS.$dns_counter=$dns" >> "$safe_domain/$year/san.cnf"
        ((dns_counter++))
    done

    # IP ekleme
    ip_counter=1
    for ip in "${ip_list[@]}"; do
        echo "IP.$ip_counter=$ip" >> "$safe_domain/$year/san.cnf"
        ((ip_counter++))
    done
fi

if command -v nano &> /dev/null; then
    echo "[+] san.cnf dosyası nano ile açılıyor..."
    nano "$safe_domain/$year/san.cnf"
else
    echo "[-] nano yüklü değil. san.cnf dosyasını manuel düzenleyin: $safe_domain/$year/san.cnf"
fi

echo "[+] Private key oluşturuluyor: $safe_domain.key"
openssl genrsa -out "$safe_domain/$year/$safe_domain.key" 2048

echo "[+] Sertifika isteği oluşturuluyor: $safe_domain.csr"
openssl req -new -key "$safe_domain/$year/$safe_domain.key" -out "$safe_domain/$year/$safe_domain.csr" -config "$safe_domain/$year/san.cnf"

echo "[+] İşlem tamamlandı!"
