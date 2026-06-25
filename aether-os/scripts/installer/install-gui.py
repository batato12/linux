#!/usr/bin/env python3
"""
Aether OS - Instalador Gráfico
Instalador baseado em PyQt6 para instalação com interface gráfica moderna
"""

import sys
import os
import subprocess
import json
from datetime import datetime
from pathlib import Path

try:
    from PyQt6.QtWidgets import (
        QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
        QLabel, QPushButton, QStackedWidget, QListWidget, QListWidgetItem,
        QComboBox, QLineEdit, QCheckBox, QProgressBar, QTextEdit, QMessageBox,
        QFileDialog, QWizard, QWizardPage, QFormLayout, QGroupBox, QRadioButton,
        QButtonGroup, QSplitter, QFrame
    )
    from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize
    from PyQt6.QtGui import QFont, QIcon, QPixmap, QPainter, QColor
except ImportError:
    print("PyQt6 não disponível. Execute: pip install PyQt6")
    sys.exit(1)


# ============================================================================
# CONFIGURAÇÕES GERAIS
# ============================================================================

INSTALLER_VERSION = "1.0.0"
APP_NAME = "Aether OS Installer"
LOG_FILE = "/var/log/aether-install-gui.log"


# ============================================================================
# THREAD DE INSTALAÇÃO
# ============================================================================

class InstallThread(QThread):
    """Thread que executa a instalação em background"""
    
    progress = pyqtSignal(int, str)  # percentagem, mensagem
    finished = pyqtSignal(bool, str)  # sucesso, mensagem
    
    def __init__(self, config):
        super().__init__()
        self.config = config
        self._abort = False
    
    def run(self):
        try:
            self.install()
            self.finished.emit(True, "Instalação concluída com sucesso!")
        except Exception as e:
            self.finished.emit(False, str(e))
    
    def abort(self):
        self._abort = True
    
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] {message}"
        print(log_msg)
        # Em produção, escrever em LOG_FILE
    
    def install(self):
        """Executa os passos da instalação"""
        
        steps = [
            ("Preparando...", 5),
            ("Criando partições...", 15),
            ("Formatando sistemas de arquivos...", 25),
            ("Instalando sistema base...", 45),
            ("Configurando sistema...", 65),
            ("Instalando bootloader...", 80),
            ("Configurando usuário...", 90),
            ("Finalizando...", 100),
        ]
        
        for msg, progress in steps:
            if self._abort:
                raise InterruptedError("Instalação cancelada pelo usuário")
            
            self.progress.emit(progress, msg)
            self.log(msg)
            
            # Simular tempo de processamento
            self.msleep(500)
            
            # Em produção, chamar scripts reais de instalação
            # self.run_install_step(msg)
        
        self.log("Instalação completada!")


# ============================================================================
# PÁGINAS DO WIZARD
# ============================================================================

class WelcomePage(QWizardPage):
    """Página de boas-vindas"""
    
    def __init__(self):
        super().__init__()
        self.setTitle("Bem-vindo ao Aether OS")
        self.setSubtitle(f"Versão {INSTALLER_VERSION}")
        
        layout = QVBoxLayout()
        
        # Logo/Imagem
        logo_label = QLabel("AETHER OS")
        logo_label.setStyleSheet("""
            font-size: 48px;
            font-weight: bold;
            color: #3498db;
            padding: 20px;
        """)
        logo_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(logo_label)
        
        # Descrição
        desc = QLabel("""
        <h3>Instalador do Aether OS</h3>
        <p>Este assistente irá guiá-lo através do processo de 
        instalação do Aether OS no seu computador.</p>
        <p><b>Recursos:</b></p>
        <ul>
            <li>Kernel Linux 6.6 LTS otimizado</li>
            <li>Suporte a UEFI e BIOS</li>
            <li>Ambiente gráfico KDE Plasma moderno</li>
            <li>Gerenciador de pacotes APM próprio</li>
            <li>Sistema de arquivos BTRFS com snapshots</li>
            <li>Suporte completo a AMD, Intel e NVIDIA</li>
        </ul>
        <p><i>Recomendamos fechar todos os aplicativos antes de continuar.</i></p>
        """)
        desc.setWordWrap(True)
        layout.addWidget(desc)
        
        layout.addStretch()
        self.setLayout(layout)
    
    def nextId(self):
        return 1


class DiskSelectionPage(QWizardPage):
    """Página de seleção de disco"""
    
    def __init__(self):
        super().__init__()
        self.setTitle("Selecionar Disco")
        self.setSubtitle("Escolha onde instalar o Aether OS")
        
        layout = QVBoxLayout()
        
        # Aviso
        warning = QLabel("""
        <span style="color: red; font-weight: bold;">
        ⚠ ATENÇÃO: Todos os dados no disco selecionado serão apagados!
        </span>
        """)
        warning.setWordWrap(True)
        layout.addWidget(warning)
        
        # Lista de discos
        self.disk_list = QListWidget()
        self.disks = self.detect_disks()
        
        for disk in self.disks:
            item = QListWidgetItem(f"{disk['device']} - {disk['size']} ({disk['model']})")
            item.setData(Qt.ItemDataRole.UserRole, disk)
            self.disk_list.addItem(item)
        
        layout.addWidget(QLabel("Discos disponíveis:"))
        layout.addWidget(self.disk_list)
        
        # Opções de particionamento
        group = QGroupBox("Esquema de Particionamento")
        form = QFormLayout()
        
        self.auto_radio = QRadioButton("Automático (EFI + Root)")
        self.manual_radio = QRadioButton("Manual (avançado)")
        
        form.addRow(self.auto_radio)
        form.addRow(self.manual_radio)
        group.setLayout(form)
        layout.addWidget(group)
        
        self.auto_radio.setChecked(True)
        
        layout.addStretch()
        self.setLayout(layout)
    
    def detect_disks(self):
        """Detecta discos disponíveis no sistema"""
        disks = []
        
        try:
            result = subprocess.run(
                ["lsblk", "-ndpo", "NAME,SIZE,MODEL,TYPE"],
                capture_output=True, text=True
            )
            
            for line in result.stdout.strip().split('\n'):
                parts = line.split()
                if len(parts) >= 4 and parts[3] == 'disk':
                    disks.append({
                        'device': parts[0],
                        'size': parts[1],
                        'model': ' '.join(parts[2:-1]) if len(parts) > 3 else 'Unknown',
                        'type': 'disk'
                    })
        except Exception as e:
            print(f"Erro ao detectar discos: {e}")
            # Fallback
            disks = [
                {'device': '/dev/sda', 'size': '500G', 'model': 'Virtual Disk', 'type': 'disk'}
            ]
        
        return disks
    
    def selected_disk(self):
        """Retorna o disco selecionado"""
        current = self.disk_list.currentItem()
        if current:
            return current.data(Qt.ItemDataRole.UserRole)
        return None
    
    def isComplete(self):
        return self.selected_disk() is not None
    
    def nextId(self):
        return 2


class UserConfigPage(QWizardPage):
    """Página de configuração do usuário"""
    
    def __init__(self):
        super().__init__()
        self.setTitle("Configurar Usuário")
        self.setSubtitle("Crie sua conta de usuário")
        
        layout = QVBoxLayout()
        
        form = QFormLayout()
        
        # Nome completo
        self.full_name = QLineEdit()
        self.full_name.setPlaceholderText("Ex: João Silva")
        form.addRow("Nome completo:", self.full_name)
        
        # Nome de usuário
        self.username = QLineEdit()
        self.username.setPlaceholderText("Ex: joao")
        form.addRow("Nome de usuário:", self.username)
        self.full_name.textChanged.connect(self.update_username)
        
        # Senha
        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("Senha:", self.password)
        
        # Confirmar senha
        self.confirm_password = QLineEdit()
        self.confirm_password.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("Confirmar senha:", self.confirm_password)
        
        layout.addLayout(form)
        
        # Opções adicionais
        group = QGroupBox("Opções")
        opt_layout = QVBoxLayout()
        
        self.auto_login = QCheckBox("Login automático")
        self.require_password = QCheckBox("Exigir senha para ações administrativas")
        self.require_password.setChecked(True)
        
        opt_layout.addWidget(self.auto_login)
        opt_layout.addWidget(self.require_password)
        group.setLayout(opt_layout)
        layout.addWidget(group)
        
        layout.addStretch()
        self.setLayout(layout)
    
    def update_username(self):
        """Atualiza username baseado no nome completo"""
        name = self.full_name.text().lower().split()[0] if self.full_name.text() else ""
        if name and not self.username.text():
            self.username.setText(name)
    
    def isComplete(self):
        return (
            self.full_name.text() and
            self.username.text() and
            self.password.text() and
            self.password.text() == self.confirm_password.text()
        )
    
    def nextId(self):
        return 3


class SummaryPage(QWizardPage):
    """Página de resumo"""
    
    def __init__(self):
        super().__init__()
        self.setTitle("Resumo")
        self.setSubtitle("Revise as configurações antes de instalar")
        
        layout = QVBoxLayout()
        
        self.summary_text = QTextEdit()
        self.summary_text.setReadOnly(True)
        self.summary_text.setMaximumHeight(300)
        layout.addWidget(self.summary_text)
        
        # Checkbox de confirmação
        self.confirm = QCheckBox("Entendo que todos os dados no disco serão apagados")
        layout.addWidget(self.confirm)
        
        layout.addStretch()
        self.setLayout(layout)
    
    def initializePage(self):
        """Popula o resumo com as configurações"""
        wizard = self.wizard()
        
        disk = wizard.get_field('disk')
        username = wizard.get_field('username')
        
        summary = f"""
<h3>Configurações de Instalação</h3>

<b>Disco:</b> {disk['device'] if disk else 'N/A'}
<b>Tamanho:</b> {disk['size'] if disk else 'N/A'}

<b>Usuário:</b> {username}
<b>Login automático:</b> {'Sim' if wizard.get_field('auto_login') else 'Não'}

<b>Sistema de arquivos:</b> BTRFS
<b>Bootloader:</b> GRUB (UEFI + BIOS)

<b>Timezone:</b> America/Sao_Paulo
<b>Idioma:</b> Português (Brasil)
"""
        self.summary_text.setHtml(summary)
    
    def isComplete(self):
        return self.confirm.isChecked()
    
    def nextId(self):
        return -1  # Última página


class InstallPage(QWizardPage):
    """Página de instalação em andamento"""
    
    def __init__(self):
        super().__init__()
        self.setTitle("Instalando")
        self.setSubtitle("Aguarde enquanto o sistema é instalado")
        
        layout = QVBoxLayout()
        
        # Barra de progresso
        self.progress = QProgressBar()
        self.progress.setMinimum(0)
        self.progress.setMaximum(100)
        layout.addWidget(self.progress)
        
        # Status atual
        self.status_label = QLabel("Preparando...")
        self.status_label.setStyleSheet("font-size: 14px; padding: 10px;")
        layout.addWidget(self.status_label)
        
        # Log detalhado
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setFontFamily("monospace")
        self.log_text.setMaximumHeight(200)
        layout.addWidget(QLabel("Log:"))
        layout.addWidget(self.log_text)
        
        layout.addStretch()
        self.setLayout(layout)
    
    def initializePage(self):
        """Inicia a instalação"""
        wizard = self.wizard()
        
        self.install_thread = InstallThread(wizard.get_config())
        self.install_thread.progress.connect(self.update_progress)
        self.install_thread.finished.connect(self.install_finished)
        self.install_thread.start()
    
    def update_progress(self, value, message):
        """Atualiza UI com progresso"""
        self.progress.setValue(value)
        self.status_label.setText(message)
        self.log_text.append(f"[{datetime.now().strftime('%H:%M:%S')}] {message}")
    
    def install_finished(self, success, message):
        """Chamado quando instalação termina"""
        if success:
            QMessageBox.information(self, "Sucesso", message)
            self.wizard().accept()
        else:
            QMessageBox.critical(self, "Erro", f"Falha na instalação:\n{message}")
            self.wizard().reject()
    
    def isComplete(self):
        return False  # Página finalizada automaticamente


# ============================================================================
# WIZARD PRINCIPAL
# ============================================================================

class InstallerWizard(QWizard):
    """Wizard principal do instalador"""
    
    def __init__(self):
        super().__init__()
        
        self.setWindowTitle(APP_NAME)
        self.setMinimumSize(700, 550)
        self.resize(800, 600)
        
        # Configurações
        self.setOption(QWizard.WizardOption.NoBackButtonOnStartPage, True)
        self.setOption(QWizard.WizardOption.HelpButtonOnRight, True)
        
        # Campos para armazenar dados entre páginas
        self._fields = {}
        
        # Adicionar páginas
        self.addPage(WelcomePage())
        self.addPage(DiskSelectionPage())
        self.addPage(UserConfigPage())
        self.addPage(SummaryPage())
        self.addPage(InstallPage())
    
    def get_field(self, name):
        """Obtém valor de campo"""
        return self._fields.get(name)
    
    def set_field(self, name, value):
        """Define valor de campo"""
        self._fields[name] = value
    
    def get_config(self):
        """Retorna configuração completa para instalação"""
        disk_page = self.page(1)
        user_page = self.page(2)
        
        return {
            'disk': disk_page.selected_disk() if disk_page else None,
            'partition_scheme': 'auto' if disk_page and disk_page.auto_radio.isChecked() else 'manual',
            'username': user_page.username.text() if user_page else '',
            'full_name': user_page.full_name.text() if user_page else '',
            'password': user_page.password.text() if user_page else '',
            'auto_login': user_page.auto_login.isChecked() if user_page else False,
            'timezone': 'America/Sao_Paulo',
            'language': 'pt_BR',
            'filesystem': 'btrfs',
        }


# ============================================================================
# FUNÇÃO MAIN
# ============================================================================

def main():
    app = QApplication(sys.argv)
    app.setApplicationName(APP_NAME)
    app.setStyle("Fusion")
    
    # Palette customizada
    palette = app.palette()
    palette.setColor(palette.ColorRole.Window, QColor(53, 53, 53))
    palette.setColor(palette.ColorRole.WindowText, Qt.GlobalColor.white)
    palette.setColor(palette.ColorRole.Base, QColor(25, 25, 25))
    palette.setColor(palette.ColorRole.AlternateBase, QColor(53, 53, 53))
    palette.setColor(palette.ColorRole.Text, Qt.GlobalColor.white)
    palette.setColor(palette.ColorRole.Button, QColor(53, 53, 53))
    palette.setColor(palette.ColorRole.ButtonText, Qt.GlobalColor.white)
    palette.setColor(palette.ColorRole.BrightText, Qt.GlobalColor.black)
    palette.setColor(palette.ColorRole.Highlight, QColor(52, 152, 219))
    palette.setColor(palette.ColorRole.HighlightedText, Qt.GlobalColor.black)
    app.setPalette(palette)
    
    # Criar e mostrar wizard
    wizard = InstallerWizard()
    wizard.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
