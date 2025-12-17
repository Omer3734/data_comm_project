import socket
import random

HOST = '0.0.0.0'
PORT = 65432


def get_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP


def apply_error(data, control):
    chance = random.random()

    if chance > 0.30:
        print(f"\n [DURUM: TEMİZ] Veri ve Kod Sağlam İletiliyor.")
        return data, control

    target = random.choice(['DATA', 'CONTROL'])
    method = random.choice(['FLIP', 'SWAP'])

    c_data = data
    c_control = control

    print(f"\n [SALDIRI TESPİT EDİLDİ] Hedef: {target} | Yöntem: {method}")

    def do_swap(text):
        if len(text) < 2:
            return text

        chars = list(text)
        idx = random.randint(0, len(chars) - 2)
        chars[idx], chars[idx + 1] = chars[idx + 1], chars[idx]
        return "".join(chars)

    def do_flip(text):
        if len(text) < 1:
            return text
        idx = random.randint(0, len(text) - 1)
        b = bytearray(text, 'utf-8')
        b[idx] ^= (1 << random.randint(0, 7))
        return b.decode('utf-8', errors='replace')

    if target == 'DATA':
        if method == 'SWAP' and len(c_data) >= 2:
            c_data = do_swap(c_data)
            print(f"️ Veri Karıştırıldı (Swap): {data} -> {c_data}")
        else:
            c_data = do_flip(c_data)
            print(f"️ Veri Değiştirildi (Flip): {data} -> {c_data}")

    else:
        if method == 'SWAP' and len(c_control) >= 2:
            c_control = do_swap(c_control)
            print(f"️ Kod Karıştırıldı (Swap): {control} -> {c_control}")
        else:
            c_control = do_flip(c_control)
            print(f"️ Kod Değiştirildi (Flip): {control} -> {c_control}")

    return c_data, c_control


def start_server():
    print(f"Server Başlatıldı: {get_ip()}:{PORT}")
    print("Telefonlardan bu IP adresini girerek bağlanın.")

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind((HOST, PORT))
    server.listen()

    while True:
        print("\n--- YENİ TUR BEKLENİYOR ---")
        print("1. Alıcı (Client 2) bekleniyor...")
        conn_recv, addr_recv = server.accept()
        print(f"Alıcı Bağlandı: {addr_recv}")

        print("2. Gönderici (Client 1) bekleniyor...")
        conn_send, addr_send = server.accept()
        print(f"Gönderici Bağlandı: {addr_send}")

        try:
            full_packet = conn_send.recv(4096).decode()
            if full_packet:
                print(f"Gelen: {full_packet}")
                data, method, control = full_packet.split('|')

                bad_data, bad_control = apply_error(data, control)

                final_packet = f"{bad_data}|{method}|{bad_control}"
                conn_recv.send(final_packet.encode())
                print(f"İletilen: {final_packet}")
        except Exception as e:
            print(f"Hata oluştu: {e}")

        conn_send.close()
        conn_recv.close()
        print("Bağlantılar kapatıldı, döngü başa dönüyor.")


if __name__ == "__main__":
    start_server()
