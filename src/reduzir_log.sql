/**
* Script de redução do Log do banco de dados, funcionamento em cascata
*
* Lucas Mota Vieira - 07/06/2017
*/

-- Definindo ambiente para execução do script
USE master

-- Variável que irá armazenar o tamanho final do arquivo log, padrão: 1 mb
DECLARE @size int
SET @size = 1 -- default 1mb

-- Declaração da tabela auxiliar que irá filtrar as bases que iremos trabalhar
DECLARE @bases TABLE (id int, nome varchar(max))

-- Aqui é filtrado as tabelas que iremos trabalhar, por padrão todas menos as bases de sistema
INSERT @bases(id, nome) SELECT dbid, name FROM master.dbo.sysdatabases WHERE name NOT IN ('master', 'tempdb', 'msdb', 'tempdb')

-- Início do looping para varrer a tabela de bases
DECLARE c CURSOR READ_ONLY FAST_FORWARD FOR
	select id from @bases

-- Variável auxiliar contador
DECLARE @id int

-- Abre o cursor
OPEN c

-- Chama o próximo da lista do cursor
FETCH NEXT FROM c INTO @id

-- Varre enquanto ok
WHILE (@@FETCH_STATUS = 0)
BEGIN
	-- Try para evitar que o looping pare por alqum erro não previsto
	BEGIN TRY 
		-- Variável que conterá o nome da base
		DECLARE @nome varchar(max)

		-- Popula a variável do cursor atual
		SET @nome = (SELECT nome from @bases where id = @id)

		-- Variável que conterá o nome lógico do arquivo log do banco de dados
		DECLARE @log_file varchar(max)

		-- Popula a variável com o nome do log do banco
		SET @log_file = (SELECT top 1 name FROM sys.master_files WHERE database_id = @id AND type = 1)

		-- Query que será chamado para executar em segundo plano
		DECLARE @query varchar(max)
		
		/*
		Tarefas:
		- Utiliza O banco do cursor
		- Desativa o log do banco
		- Reduz o log para o tamanho informado
		- Ativa o log do banco
		Mais sobre RECOVERY SIMPLE/FULL: https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server
		*/
		SET @query = '
		USE [' + @nome + '];

		ALTER DATABASE [' + @nome + ']
		SET RECOVERY SIMPLE;

		DBCC SHRINKFILE (''' + @log_file + ''', ' + cast(@size as varchar(max)) + ');

		ALTER DATABASE [' + @nome + ']
		SET RECOVERY FULL;'
		
		-- Executa o script anterior
		EXEC (@query)
	END TRY  
	BEGIN CATCH  
		-- Demonstra o erro na tela
		SELECT  
			ERROR_NUMBER() AS ErrorNumber  
			,ERROR_SEVERITY() AS ErrorSeverity  
			,ERROR_STATE() AS ErrorState  
			,ERROR_PROCEDURE() AS ErrorProcedure  
			,ERROR_LINE() AS ErrorLine  
			,ERROR_MESSAGE() AS ErrorMessage;  
	END CATCH; 

	-- Chama o próximo do lopping
	FETCH NEXT FROM c INTO @id
END

-- Fecha o cursor
CLOSE c

-- Destroi a variável
DEALLOCATE c
